/// Eventos do sistema WebSocket.
///
/// Estes são os eventos internos do protocolo.
/// Eventos de domínio devem ser definidos pela aplicação.
abstract class WsEvents {
  WsEvents._();

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  /// Cliente conectou com sucesso
  static const String connect = 'sys.connect';

  /// Cliente desconectou
  static const String disconnect = 'sys.disconnect';

  /// Cliente reconectou com sessão existente
  static const String reconnect = 'sys.reconnect';

  // ══════════════════════════════════════════════════════════════════════════
  // HEARTBEAT
  // ══════════════════════════════════════════════════════════════════════════

  /// Ping do servidor para cliente
  static const String ping = 'sys.ping';

  /// Pong do cliente para servidor
  static const String pong = 'sys.pong';

  // ══════════════════════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Request de autenticação
  static const String authRequest = 'sys.auth.request';

  /// Resposta de autenticação (sucesso)
  static const String authSuccess = 'sys.auth.success';

  /// Resposta de autenticação (falha)
  static const String authFailure = 'sys.auth.failure';

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION
  // ══════════════════════════════════════════════════════════════════════════

  /// Sessão criada
  static const String sessionCreated = 'sys.session.created';

  /// Sessão restaurada (reconexão)
  static const String sessionRestored = 'sys.session.restored';

  /// Sessão suspensa (queda detectada)
  static const String sessionSuspended = 'sys.session.suspended';

  /// Sessão encerrada
  static const String sessionClosed = 'sys.session.closed';

  // ══════════════════════════════════════════════════════════════════════════
  // ROOMS
  // ══════════════════════════════════════════════════════════════════════════

  /// Entrou em uma sala
  static const String roomJoined = 'sys.room.joined';

  /// Saiu de uma sala
  static const String roomLeft = 'sys.room.left';

  /// Mensagem broadcast na sala
  static const String roomBroadcast = 'sys.room.broadcast';

  // ══════════════════════════════════════════════════════════════════════════
  // ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Erro genérico
  static const String error = 'sys.error';

  /// Erro de protocolo (versão inválida, formato inválido)
  static const String protocolError = 'sys.error.protocol';

  /// Erro de autenticação
  static const String authError = 'sys.error.auth';

  /// Erro de handler não encontrado
  static const String handlerNotFound = 'sys.error.handler_not_found';

  /// Erro de validação
  static const String validationError = 'sys.error.validation';
}

/// Códigos de erro padrão
abstract class WsErrorCodes {
  WsErrorCodes._();

  /// Erro desconhecido
  static const int unknown = 1000;

  /// Protocolo inválido
  static const int invalidProtocol = 1001;

  /// Versão não suportada
  static const int unsupportedVersion = 1002;

  /// Autenticação requerida
  static const int authRequired = 1003;

  /// Autenticação falhou
  static const int authFailed = 1004;

  /// Token expirado
  static const int tokenExpired = 1005;

  /// Sessão não encontrada
  static const int sessionNotFound = 1006;

  /// Sessão duplicada
  static const int sessionDuplicate = 1007;

  /// Handler não encontrado
  static const int handlerNotFound = 1008;

  /// Validação falhou
  static const int validationFailed = 1009;

  /// Rate limit excedido
  static const int rateLimitExceeded = 1010;

  /// Sala não encontrada
  static const int roomNotFound = 1011;

  /// Sem permissão
  static const int forbidden = 1012;

  /// Erro interno do servidor
  static const int internalError = 1500;
}

/// Close codes para WebSocket
abstract class WsCloseCodes {
  WsCloseCodes._();

  /// Fechamento normal
  static const int normalClosure = 1000;

  /// Servidor indo embora
  static const int goingAway = 1001;

  /// Erro de protocolo
  static const int protocolError = 1002;

  /// Dados inválidos
  static const int unsupportedData = 1003;

  /// Mensagem muito grande
  static const int messageTooLarge = 1009;

  /// Erro interno
  static const int internalError = 1011;

  /// Autenticação requerida
  static const int authRequired = 4001;

  /// Autenticação falhou
  static const int authFailed = 4002;

  /// Sessão duplicada (forçando desconexão)
  static const int sessionDuplicate = 4003;

  /// Timeout de inatividade
  static const int inactivityTimeout = 4004;

  /// Sessão expirada
  static const int sessionExpired = 4005;
}
