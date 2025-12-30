import '../connection/connection.dart';

/// Resultado da autenticação
class AuthResult {
  /// Se a autenticação foi bem-sucedida
  final bool success;

  /// ID do usuário (se autenticado)
  final String? userId;

  /// Metadados adicionais do usuário
  final Map<String, dynamic>? metadata;

  /// Mensagem de erro (se falhou)
  final String? error;

  /// Código de erro (se falhou)
  final int? errorCode;

  const AuthResult.success({required this.userId, this.metadata})
    : success = true,
      error = null,
      errorCode = null;

  const AuthResult.failure({required this.error, this.errorCode})
    : success = false,
      userId = null,
      metadata = null;

  @override
  String toString() => success
      ? 'AuthResult.success(userId: $userId)'
      : 'AuthResult.failure(error: $error)';
}

/// Interface de autenticação plugável.
///
/// O package NÃO implementa autenticação.
/// Você deve implementar esta interface conforme sua estratégia:
/// - JWT
/// - Token custom
/// - API key
/// - Etc.
abstract class WsAuthenticator {
  const WsAuthenticator();

  /// Autentica uma conexão.
  ///
  /// [connection] - a conexão WebSocket
  /// [token] - token de autenticação (pode vir do header, query param, ou primeira mensagem)
  ///
  /// Retorna [AuthResult] indicando sucesso ou falha.
  Future<AuthResult> authenticate(WsConnection connection, String? token);

  /// Valida se um token ainda é válido (opcional).
  ///
  /// Usado para verificação periódica ou em reconexão.
  Future<bool> validateToken(String token) async => true;

  /// Extrai token do request HTTP (antes do upgrade).
  ///
  /// Por padrão, tenta query parameter 'token' ou header 'Authorization'.
  String? extractTokenFromRequest(Uri uri, Map<String, String> headers) {
    // Tenta query parameter
    final queryToken = uri.queryParameters['token'];
    if (queryToken != null && queryToken.isNotEmpty) {
      return queryToken;
    }

    // Tenta header Authorization (Bearer)
    final authHeader = headers['authorization'] ?? headers['Authorization'];
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }

    return null;
  }
}

/// Authenticator que permite qualquer conexão (desenvolvimento/teste).
///
/// ⚠️ NÃO USE EM PRODUÇÃO!
class NoAuthAuthenticator extends WsAuthenticator {
  const NoAuthAuthenticator();

  @override
  Future<AuthResult> authenticate(
    WsConnection connection,
    String? token,
  ) async {
    return AuthResult.success(userId: 'anonymous_${connection.connectionId}');
  }
}

/// Authenticator baseado em callback.
///
/// Útil para integração rápida sem criar uma classe.
class CallbackAuthenticator extends WsAuthenticator {
  final Future<AuthResult> Function(WsConnection connection, String? token)
  _callback;

  const CallbackAuthenticator(this._callback);

  @override
  Future<AuthResult> authenticate(WsConnection connection, String? token) {
    return _callback(connection, token);
  }
}

/// Mixin para autenticação que requer token obrigatório
mixin RequiresToken on WsAuthenticator {
  @override
  Future<AuthResult> authenticate(
    WsConnection connection,
    String? token,
  ) async {
    if (token == null || token.isEmpty) {
      return const AuthResult.failure(
        error: 'Authentication token required',
        errorCode: 4001,
      );
    }
    return authenticateWithToken(connection, token);
  }

  /// Método a ser implementado com token garantido não-nulo
  Future<AuthResult> authenticateWithToken(
    WsConnection connection,
    String token,
  );
}
