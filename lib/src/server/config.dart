/// Configuração do servidor WebSocket
class WsServerConfig {
  /// Host para bind
  final String host;

  /// Porta para bind
  final int port;

  /// Path para upgrade WebSocket
  final String path;

  /// Versão atual do protocolo
  final String protocolVersion;

  /// Versões suportadas
  final Set<String> supportedVersions;

  /// Intervalo de heartbeat
  final Duration heartbeatInterval;

  /// Timeout de heartbeat
  final Duration heartbeatTimeout;

  /// Timeout para sessões suspensas
  final Duration sessionSuspendTimeout;

  /// Intervalo de cleanup de sessões
  final Duration sessionCleanupInterval;

  /// Se deve solicitar autenticação imediatamente
  final bool requireAuth;

  /// Tempo máximo para autenticação após conexão
  final Duration authTimeout;

  /// Tamanho máximo de mensagem (bytes)
  final int maxMessageSize;

  /// Se deve usar compressão
  final bool enableCompression;

  /// Headers CORS permitidos
  final Map<String, String>? corsHeaders;

  const WsServerConfig({
    this.host = 'localhost',
    this.port = 8080,
    this.path = '/ws',
    this.protocolVersion = '1.0',
    this.supportedVersions = const {'1.0'},
    this.heartbeatInterval = const Duration(seconds: 30),
    this.heartbeatTimeout = const Duration(seconds: 10),
    this.sessionSuspendTimeout = const Duration(minutes: 5),
    this.sessionCleanupInterval = const Duration(seconds: 30),
    this.requireAuth = false,
    this.authTimeout = const Duration(seconds: 30),
    this.maxMessageSize = 64 * 1024, // 64KB
    this.enableCompression = true,
    this.corsHeaders,
  });

  /// Cria cópia com modificações
  WsServerConfig copyWith({
    String? host,
    int? port,
    String? path,
    String? protocolVersion,
    Set<String>? supportedVersions,
    Duration? heartbeatInterval,
    Duration? heartbeatTimeout,
    Duration? sessionSuspendTimeout,
    Duration? sessionCleanupInterval,
    bool? requireAuth,
    Duration? authTimeout,
    int? maxMessageSize,
    bool? enableCompression,
    Map<String, String>? corsHeaders,
  }) {
    return WsServerConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      path: path ?? this.path,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      supportedVersions: supportedVersions ?? this.supportedVersions,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
      heartbeatTimeout: heartbeatTimeout ?? this.heartbeatTimeout,
      sessionSuspendTimeout:
          sessionSuspendTimeout ?? this.sessionSuspendTimeout,
      sessionCleanupInterval:
          sessionCleanupInterval ?? this.sessionCleanupInterval,
      requireAuth: requireAuth ?? this.requireAuth,
      authTimeout: authTimeout ?? this.authTimeout,
      maxMessageSize: maxMessageSize ?? this.maxMessageSize,
      enableCompression: enableCompression ?? this.enableCompression,
      corsHeaders: corsHeaders ?? this.corsHeaders,
    );
  }

  /// URI do servidor
  String get uri => 'ws://$host:$port$path';

  @override
  String toString() => 'WsServerConfig($uri)';
}
