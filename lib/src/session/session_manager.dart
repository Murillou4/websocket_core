import 'dart:async';

import '../connection/connection.dart';
import '../utils/id_generator.dart';
import 'session.dart';

/// Callback para eventos de sessão
typedef SessionCallback = void Function(WsSession session);

/// Gerenciador de sessões WebSocket.
///
/// Responsabilidades:
/// - Criar/buscar/encerrar sessões
/// - Gerenciar reconexão (troca de conexão)
/// - Timeout para sessões suspensas
/// - Prevenção de duplicação
class WsSessionManager {
  /// Gerador de IDs de sessão
  final IdGenerator _idGenerator;

  /// Timeout para sessões suspensas (milissegundos)
  final Duration suspendTimeout;

  /// Mapa de sessões por sessionId
  final Map<String, WsSession> _sessions = {};

  /// Mapa de sessões por userId
  final Map<String, Set<String>> _userSessions = {};

  /// Timer para cleanup de sessões expiradas
  Timer? _cleanupTimer;

  /// Intervalo de cleanup
  final Duration cleanupInterval;

  /// Callbacks de sessão criada
  final List<SessionCallback> _onSessionCreatedCallbacks = [];

  /// Callbacks de sessão suspensa
  final List<SessionCallback> _onSessionSuspendedCallbacks = [];

  /// Callbacks de sessão fechada
  final List<SessionCallback> _onSessionClosedCallbacks = [];

  /// Callbacks de reconexão
  final List<SessionCallback> _onSessionReconnectedCallbacks = [];

  WsSessionManager({
    IdGenerator? idGenerator,
    this.suspendTimeout = const Duration(minutes: 5),
    this.cleanupInterval = const Duration(seconds: 30),
    bool autoCleanup = true,
  }) : _idGenerator = idGenerator ?? const UuidGenerator() {
    if (autoCleanup) {
      _startCleanupTimer();
    }
  }

  /// Número de sessões totais
  int get sessionCount => _sessions.length;

  /// Número de sessões ativas
  int get activeSessionCount =>
      _sessions.values.where((s) => s.isActive).length;

  /// Número de sessões suspensas
  int get suspendedSessionCount =>
      _sessions.values.where((s) => s.isSuspended).length;

  /// Lista de IDs de sessões
  Iterable<String> get sessionIds => _sessions.keys;

  /// Lista de sessões
  Iterable<WsSession> get sessions => _sessions.values;

  /// Cria uma nova sessão
  WsSession createSession({
    String? userId,
    WsConnection? connection,
    Map<String, dynamic>? metadata,
  }) {
    final sessionId = _idGenerator.generate();

    final session = WsSession(
      sessionId: sessionId,
      userId: userId,
      connection: connection,
    );

    if (metadata != null) {
      session.metadata.addAll(metadata);
    }

    _sessions[sessionId] = session;

    // Registra no índice por userId
    if (userId != null) {
      _userSessions.putIfAbsent(userId, () => {}).add(sessionId);
    }

    // Notifica callbacks
    for (final callback in _onSessionCreatedCallbacks) {
      callback(session);
    }

    return session;
  }

  /// Busca sessão por ID
  WsSession? getSession(String sessionId) {
    return _sessions[sessionId];
  }

  /// Busca sessões por userId
  List<WsSession> getSessionsByUserId(String userId) {
    final sessionIds = _userSessions[userId];
    if (sessionIds == null) return [];

    return sessionIds
        .map((id) => _sessions[id])
        .whereType<WsSession>()
        .toList();
  }

  /// Verifica se uma sessão existe
  bool hasSession(String sessionId) {
    return _sessions.containsKey(sessionId);
  }

  /// Reconecta uma sessão existente com nova conexão
  ///
  /// Retorna a sessão se reconexão for bem-sucedida, null caso contrário.
  WsSession? reconnect(String sessionId, WsConnection newConnection) {
    final session = _sessions[sessionId];
    if (session == null) return null;

    // Não permite reconexão de sessão fechada
    if (session.isClosed) return null;

    // Atualiza conexão
    session.updateConnection(newConnection);

    // Notifica callbacks
    for (final callback in _onSessionReconnectedCallbacks) {
      callback(session);
    }

    return session;
  }

  /// Suspende uma sessão (queda de conexão)
  void suspendSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null || session.isClosed) return;

    session.suspend();

    // Notifica callbacks
    for (final callback in _onSessionSuspendedCallbacks) {
      callback(session);
    }
  }

  /// Fecha uma sessão
  Future<void> closeSession(
    String sessionId, [
    int? closeCode,
    String? reason,
  ]) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    // Remove do índice por userId
    if (session.userId != null) {
      _userSessions[session.userId]?.remove(sessionId);
      if (_userSessions[session.userId]?.isEmpty ?? false) {
        _userSessions.remove(session.userId);
      }
    }

    // Fecha a sessão
    await session.close(closeCode, reason);

    // Remove do mapa principal
    _sessions.remove(sessionId);

    // Notifica callbacks
    for (final callback in _onSessionClosedCallbacks) {
      callback(session);
    }
  }

  /// Fecha todas as sessões de um usuário
  Future<void> closeUserSessions(
    String userId, [
    int? closeCode,
    String? reason,
  ]) async {
    final sessionIds = _userSessions[userId]?.toList() ?? [];
    for (final sessionId in sessionIds) {
      await closeSession(sessionId, closeCode, reason);
    }
  }

  /// Fecha todas as sessões
  Future<void> closeAll([int? closeCode, String? reason]) async {
    final sessionIds = _sessions.keys.toList();
    for (final sessionId in sessionIds) {
      await closeSession(sessionId, closeCode, reason);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CALLBACKS
  // ══════════════════════════════════════════════════════════════════════════

  /// Registra callback para sessão criada
  void onSessionCreated(SessionCallback callback) {
    _onSessionCreatedCallbacks.add(callback);
  }

  /// Registra callback para sessão suspensa
  void onSessionSuspended(SessionCallback callback) {
    _onSessionSuspendedCallbacks.add(callback);
  }

  /// Registra callback para sessão fechada
  void onSessionClosed(SessionCallback callback) {
    _onSessionClosedCallbacks.add(callback);
  }

  /// Registra callback para reconexão
  void onSessionReconnected(SessionCallback callback) {
    _onSessionReconnectedCallbacks.add(callback);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ══════════════════════════════════════════════════════════════════════════

  /// Inicia timer de cleanup
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) {
      _cleanupExpiredSessions();
    });
  }

  /// Para timer de cleanup
  void stopCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Limpa sessões suspensas que expiraram
  Future<void> _cleanupExpiredSessions() async {
    final expired = <String>[];

    for (final session in _sessions.values) {
      if (session.isSuspended) {
        final suspendedDuration = session.suspendedDuration;
        if (suspendedDuration != null && suspendedDuration >= suspendTimeout) {
          expired.add(session.sessionId);
        }
      }
    }

    for (final sessionId in expired) {
      await closeSession(sessionId, 4005, 'Session expired');
    }
  }

  /// Limpa recursos
  void dispose() {
    stopCleanup();
  }
}
