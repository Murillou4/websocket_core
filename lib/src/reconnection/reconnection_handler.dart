import 'dart:async';

import '../auth/authenticator.dart';
import '../connection/connection.dart';
import '../protocol/events.dart';
import '../protocol/message.dart';
import '../session/session.dart';
import '../session/session_manager.dart';

/// Resultado da tentativa de reconexão
class ReconnectionResult {
  /// Se a reconexão foi bem-sucedida
  final bool success;

  /// Sessão reconectada (se sucesso)
  final WsSession? session;

  /// Erro (se falha)
  final String? error;

  /// Código de erro
  final int? errorCode;

  const ReconnectionResult.success(this.session)
    : success = true,
      error = null,
      errorCode = null;

  const ReconnectionResult.failure({required this.error, this.errorCode})
    : success = false,
      session = null;
}

/// Callback de reconexão
typedef ReconnectionCallback =
    void Function(WsSession session, WsConnection oldConnection);

/// Handler de reconexão.
///
/// Responsabilidades:
/// - Validar `sessionId` recebido
/// - Encerrar conexão antiga
/// - Reapontar sessão para nova conexão
/// - Hooks de restauração de estado
class ReconnectionHandler {
  /// Gerenciador de sessões
  final WsSessionManager sessionManager;

  /// Authenticator para revalidar token (opcional)
  final WsAuthenticator? authenticator;

  /// Se deve revalidar token na reconexão
  final bool revalidateToken;

  /// Versão do protocolo
  final String protocolVersion;

  /// Callbacks de reconexão bem-sucedida
  final List<ReconnectionCallback> _onReconnectedCallbacks = [];

  ReconnectionHandler({
    required this.sessionManager,
    this.authenticator,
    this.revalidateToken = false,
    this.protocolVersion = '1.0',
  });

  /// Tenta reconectar uma sessão existente
  Future<ReconnectionResult> reconnect({
    required WsConnection newConnection,
    required String sessionId,
    String? token,
  }) async {
    // 1. Busca sessão existente
    final session = sessionManager.getSession(sessionId);
    if (session == null) {
      return ReconnectionResult.failure(
        error: 'Session not found',
        errorCode: WsErrorCodes.sessionNotFound,
      );
    }

    // 2. Verifica se sessão pode ser reconectada
    if (session.isClosed) {
      return ReconnectionResult.failure(
        error: 'Session is closed',
        errorCode: WsErrorCodes.sessionNotFound,
      );
    }

    // 3. Revalida token se configurado
    if (revalidateToken && authenticator != null && token != null) {
      final isValid = await authenticator!.validateToken(token);
      if (!isValid) {
        return ReconnectionResult.failure(
          error: 'Token validation failed',
          errorCode: WsErrorCodes.tokenExpired,
        );
      }
    }

    // 4. Guarda conexão antiga para notificação
    final oldConnection = session.connection;

    // 5. Fecha conexão antiga (se existir e estiver ativa)
    if (oldConnection != null && oldConnection.isActive) {
      // Envia mensagem de desconexão antes de fechar
      try {
        final disconnectMsg = WsMessage(
          version: protocolVersion,
          event: WsEvents.disconnect,
          payload: {'reason': 'replaced_by_reconnection'},
        );
        oldConnection.send(disconnectMsg);
      } catch (_) {
        // Ignora erro de envio
      }

      // Fecha com código de sessão duplicada
      await oldConnection.close(
        WsCloseCodes.sessionDuplicate,
        'Replaced by new connection',
      );
    }

    // 6. Reconecta sessão com nova conexão
    final reconnectedSession = sessionManager.reconnect(
      sessionId,
      newConnection,
    );
    if (reconnectedSession == null) {
      return ReconnectionResult.failure(
        error: 'Failed to reconnect session',
        errorCode: WsErrorCodes.internalError,
      );
    }

    // 7. Notifica callbacks
    if (oldConnection != null) {
      for (final callback in _onReconnectedCallbacks) {
        callback(reconnectedSession, oldConnection);
      }
    }

    return ReconnectionResult.success(reconnectedSession);
  }

  /// Registra callback de reconexão
  void onReconnected(ReconnectionCallback callback) {
    _onReconnectedCallbacks.add(callback);
  }

  /// Remove callback de reconexão
  void removeOnReconnected(ReconnectionCallback callback) {
    _onReconnectedCallbacks.remove(callback);
  }

  /// Cria mensagem de sessão restaurada
  WsMessage createSessionRestoredMessage(WsSession session) {
    return WsMessage(
      version: protocolVersion,
      event: WsEvents.sessionRestored,
      payload: {
        'sessionId': session.sessionId,
        'userId': session.userId,
        'rooms': session.rooms.toList(),
        'metadata': session.metadata,
      },
    );
  }
}
