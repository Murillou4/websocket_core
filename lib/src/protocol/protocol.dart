import 'dart:convert';

import 'message.dart';

/// Resultado da validação de protocolo
class ProtocolValidationResult {
  final bool isValid;
  final String? error;
  final WsMessage? message;

  const ProtocolValidationResult.success(this.message)
    : isValid = true,
      error = null;

  const ProtocolValidationResult.failure(this.error)
    : isValid = false,
      message = null;
}

/// Gerenciador de protocolo WebSocket.
///
/// Responsabilidades:
/// - Validar estrutura de mensagens
/// - Validar versão do protocolo
/// - Serializar/deserializar mensagens
class WsProtocol {
  /// Versão atual do protocolo
  final String currentVersion;

  /// Versões suportadas (para compatibilidade)
  final Set<String> supportedVersions;

  /// Versão mínima suportada
  final String? minimumVersion;

  const WsProtocol({
    this.currentVersion = '1.0',
    this.supportedVersions = const {'1.0'},
    this.minimumVersion,
  });

  /// Valida e parseia uma mensagem raw
  ProtocolValidationResult validate(String rawMessage) {
    // Tenta parsear JSON
    Map<String, dynamic> data;
    try {
      data = json.decode(rawMessage) as Map<String, dynamic>;
    } catch (e) {
      return const ProtocolValidationResult.failure('Invalid JSON format');
    }

    // Valida campos obrigatórios
    if (!data.containsKey('e')) {
      return const ProtocolValidationResult.failure(
        'Missing required field: event (e)',
      );
    }

    final event = data['e'];
    if (event is! String || event.isEmpty) {
      return const ProtocolValidationResult.failure(
        'Invalid event: must be a non-empty string',
      );
    }

    // Valida versão
    final version = (data['v'] as String?) ?? currentVersion;
    if (!isVersionSupported(version)) {
      return ProtocolValidationResult.failure(
        'Unsupported protocol version: $version',
      );
    }

    // Valida payload (se presente, deve ser Map)
    if (data.containsKey('p') && data['p'] is! Map) {
      return const ProtocolValidationResult.failure(
        'Invalid payload: must be an object',
      );
    }

    // Cria mensagem
    try {
      final message = WsMessage.fromMap(data);
      return ProtocolValidationResult.success(message);
    } catch (e) {
      return ProtocolValidationResult.failure('Failed to parse message: $e');
    }
  }

  /// Verifica se uma versão é suportada
  bool isVersionSupported(String version) {
    // Primeiro verifica se está na lista de suportadas
    if (!supportedVersions.contains(version)) {
      return false;
    }

    // Se há versão mínima, verifica
    if (minimumVersion != null) {
      return _compareVersions(version, minimumVersion!) >= 0;
    }

    return true;
  }

  /// Serializa uma mensagem para envio
  String serialize(WsMessage message) {
    return message.toJson();
  }

  /// Cria mensagem com versão atual
  WsMessage createMessage({
    required String event,
    Map<String, dynamic> payload = const {},
    String? correlationId,
  }) {
    return WsMessage(
      version: currentVersion,
      event: event,
      payload: payload,
      correlationId: correlationId,
    );
  }

  /// Cria mensagem de erro
  WsMessage createErrorMessage({
    required int code,
    required String message,
    String? correlationId,
    Map<String, dynamic>? details,
  }) {
    return WsMessage(
      version: currentVersion,
      event: 'sys.error',
      payload: {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      },
      correlationId: correlationId,
    );
  }

  /// Compara versões (semver simplificado)
  /// Retorna: -1 se v1 < v2, 0 se iguais, 1 se v1 > v2
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.tryParse).toList();
    final parts2 = v2.split('.').map(int.tryParse).toList();

    for (var i = 0; i < parts1.length && i < parts2.length; i++) {
      final p1 = parts1[i] ?? 0;
      final p2 = parts2[i] ?? 0;
      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }

    return parts1.length.compareTo(parts2.length);
  }
}
