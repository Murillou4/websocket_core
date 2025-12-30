import '../protocol/events.dart';

/// Exceção base do WebSocket Core.
///
/// Todas as exceções do package derivam desta.
class WsException implements Exception {
  /// Mensagem de erro
  final String message;

  /// Código de erro (opcional)
  final int? code;

  /// Detalhes adicionais (opcional)
  final Map<String, dynamic>? details;

  const WsException(this.message, {this.code, this.details});

  @override
  String toString() =>
      'WsException: $message${code != null ? ' (code: $code)' : ''}';
}

// ══════════════════════════════════════════════════════════════════════════════
// PROTOCOL EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Erro de protocolo (formato inválido, versão não suportada).
class WsProtocolException extends WsException {
  const WsProtocolException(
    super.message, {
    super.code = WsErrorCodes.invalidProtocol,
    super.details,
  });
}

/// Versão de protocolo não suportada.
class WsUnsupportedVersionException extends WsProtocolException {
  /// Versão recebida
  final String version;

  /// Versões suportadas
  final Set<String> supportedVersions;

  WsUnsupportedVersionException({
    required this.version,
    required this.supportedVersions,
  }) : super(
         'Unsupported protocol version: $version',
         code: WsErrorCodes.unsupportedVersion,
         details: {'version': version, 'supported': supportedVersions.toList()},
       );
}

// ══════════════════════════════════════════════════════════════════════════════
// AUTH EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Erro de autenticação.
class WsAuthException extends WsException {
  const WsAuthException(
    super.message, {
    super.code = WsErrorCodes.authFailed,
    super.details,
  });
}

/// Autenticação requerida mas não fornecida.
class WsAuthRequiredException extends WsAuthException {
  const WsAuthRequiredException([String? message])
    : super(
        message ?? 'Authentication required',
        code: WsErrorCodes.authRequired,
      );
}

/// Token inválido ou expirado.
class WsTokenException extends WsAuthException {
  const WsTokenException([String? message])
    : super(
        message ?? 'Invalid or expired token',
        code: WsErrorCodes.tokenExpired,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SESSION EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Erro relacionado a sessão.
class WsSessionException extends WsException {
  const WsSessionException(
    super.message, {
    super.code = WsErrorCodes.sessionNotFound,
    super.details,
  });
}

/// Sessão não encontrada.
class WsSessionNotFoundException extends WsSessionException {
  final String sessionId;

  WsSessionNotFoundException(this.sessionId)
    : super(
        'Session not found: $sessionId',
        code: WsErrorCodes.sessionNotFound,
        details: {'sessionId': sessionId},
      );
}

/// Sessão duplicada (já ativa em outra conexão).
class WsSessionDuplicateException extends WsSessionException {
  final String sessionId;

  WsSessionDuplicateException(this.sessionId)
    : super(
        'Session already active: $sessionId',
        code: WsErrorCodes.sessionDuplicate,
        details: {'sessionId': sessionId},
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ROOM EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Erro relacionado a sala.
class WsRoomException extends WsException {
  const WsRoomException(
    super.message, {
    super.code = WsErrorCodes.roomNotFound,
    super.details,
  });
}

/// Sala não encontrada.
class WsRoomNotFoundException extends WsRoomException {
  final String roomId;

  WsRoomNotFoundException(this.roomId)
    : super(
        'Room not found: $roomId',
        code: WsErrorCodes.roomNotFound,
        details: {'roomId': roomId},
      );
}

/// Sala cheia.
class WsRoomFullException extends WsRoomException {
  final String roomId;
  final int maxMembers;

  WsRoomFullException(this.roomId, this.maxMembers)
    : super(
        'Room is full: $roomId (max: $maxMembers)',
        details: {'roomId': roomId, 'maxMembers': maxMembers},
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// HANDLER EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Handler não encontrado para evento.
class WsHandlerNotFoundException extends WsException {
  final String event;

  WsHandlerNotFoundException(this.event)
    : super(
        'Handler not found for event: $event',
        code: WsErrorCodes.handlerNotFound,
        details: {'event': event},
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// VALIDATION EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Erro de validação.
class WsValidationException extends WsException {
  /// Campo(s) com erro
  final Map<String, String>? fieldErrors;

  const WsValidationException(super.message, {this.fieldErrors, super.details})
    : super(code: WsErrorCodes.validationFailed);

  /// Cria exceção para campo obrigatório
  factory WsValidationException.required(String fieldName) {
    return WsValidationException(
      'Field required: $fieldName',
      fieldErrors: {fieldName: 'required'},
    );
  }

  /// Cria exceção para tipo inválido
  factory WsValidationException.invalidType(
    String fieldName,
    String expectedType,
  ) {
    return WsValidationException(
      'Invalid type for $fieldName: expected $expectedType',
      fieldErrors: {fieldName: 'invalid_type'},
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RATE LIMIT EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Rate limit excedido.
class WsRateLimitException extends WsException {
  /// Tempo até poder tentar novamente (milissegundos)
  final Duration retryAfter;

  WsRateLimitException({required this.retryAfter, String? message})
    : super(
        message ?? 'Rate limit exceeded',
        code: WsErrorCodes.rateLimitExceeded,
        details: {'retryAfterMs': retryAfter.inMilliseconds},
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// CONNECTION EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Erro de conexão.
class WsConnectionException extends WsException {
  const WsConnectionException(super.message, {super.code, super.details});
}

/// Conexão fechada.
class WsConnectionClosedException extends WsConnectionException {
  final int? closeCode;
  final String? closeReason;

  WsConnectionClosedException({this.closeCode, this.closeReason})
    : super(
        'Connection closed${closeReason != null ? ': $closeReason' : ''}',
        code: closeCode,
        details: {
          if (closeCode != null) 'closeCode': closeCode,
          if (closeReason != null) 'closeReason': closeReason,
        },
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// PERMISSION EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Sem permissão para ação.
class WsForbiddenException extends WsException {
  final String? action;
  final String? resource;

  WsForbiddenException({this.action, this.resource, String? message})
    : super(
        message ?? 'Permission denied${action != null ? ' for $action' : ''}',
        code: WsErrorCodes.forbidden,
        details: {
          if (action != null) 'action': action,
          if (resource != null) 'resource': resource,
        },
      );
}
