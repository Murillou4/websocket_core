/// Interface de métricas do WebSocket.
///
/// O package NÃO implementa métricas.
/// Você deve implementar esta interface conforme sua stack:
/// - Prometheus
/// - DataDog
/// - Custom logging
/// - Etc.
abstract class WsMetrics {
  const WsMetrics();

  /// Conexão aberta
  void onConnectionOpened();

  /// Conexão fechada
  void onConnectionClosed();

  /// Sessão criada
  void onSessionCreated();

  /// Sessão suspensa
  void onSessionSuspended();

  /// Sessão fechada
  void onSessionClosed();

  /// Reconexão bem-sucedida
  void onReconnection();

  /// Mensagem recebida
  void onMessageReceived(String event);

  /// Mensagem enviada
  void onMessageSent(String event);

  /// Erro ocorrido
  void onError(Object error);

  /// Entrada em sala
  void onRoomJoined(String roomId);

  /// Saída de sala
  void onRoomLeft(String roomId);
}

/// Métricas em memória para desenvolvimento/debugging.
///
/// Útil para testes e desenvolvimento local.
class InMemoryMetrics extends WsMetrics {
  int _connectionsOpened = 0;
  int _connectionsClosed = 0;
  int _sessionsCreated = 0;
  int _sessionsSuspended = 0;
  int _sessionsClosed = 0;
  int _reconnections = 0;
  int _messagesReceived = 0;
  int _messagesSent = 0;
  int _errors = 0;
  int _roomJoins = 0;
  int _roomLeaves = 0;

  final Map<String, int> _eventCounts = {};

  /// Conexões ativas (aproximado)
  int get activeConnections => _connectionsOpened - _connectionsClosed;

  /// Total de conexões abertas
  int get totalConnectionsOpened => _connectionsOpened;

  /// Total de sessões criadas
  int get totalSessionsCreated => _sessionsCreated;

  /// Total de reconexões
  int get totalReconnections => _reconnections;

  /// Total de mensagens recebidas
  int get totalMessagesReceived => _messagesReceived;

  /// Total de mensagens enviadas
  int get totalMessagesSent => _messagesSent;

  /// Total de erros
  int get totalErrors => _errors;

  /// Contagem por evento
  Map<String, int> get eventCounts => Map.unmodifiable(_eventCounts);

  @override
  void onConnectionOpened() {
    _connectionsOpened++;
  }

  @override
  void onConnectionClosed() {
    _connectionsClosed++;
  }

  @override
  void onSessionCreated() {
    _sessionsCreated++;
  }

  @override
  void onSessionSuspended() {
    _sessionsSuspended++;
  }

  @override
  void onSessionClosed() {
    _sessionsClosed++;
  }

  @override
  void onReconnection() {
    _reconnections++;
  }

  @override
  void onMessageReceived(String event) {
    _messagesReceived++;
    _eventCounts[event] = (_eventCounts[event] ?? 0) + 1;
  }

  @override
  void onMessageSent(String event) {
    _messagesSent++;
  }

  @override
  void onError(Object error) {
    _errors++;
  }

  @override
  void onRoomJoined(String roomId) {
    _roomJoins++;
  }

  @override
  void onRoomLeft(String roomId) {
    _roomLeaves++;
  }

  /// Reseta todas as métricas
  void reset() {
    _connectionsOpened = 0;
    _connectionsClosed = 0;
    _sessionsCreated = 0;
    _sessionsSuspended = 0;
    _sessionsClosed = 0;
    _reconnections = 0;
    _messagesReceived = 0;
    _messagesSent = 0;
    _errors = 0;
    _roomJoins = 0;
    _roomLeaves = 0;
    _eventCounts.clear();
  }

  /// Retorna snapshot das métricas
  Map<String, dynamic> toMap() {
    return {
      'connections': {
        'opened': _connectionsOpened,
        'closed': _connectionsClosed,
        'active': activeConnections,
      },
      'sessions': {
        'created': _sessionsCreated,
        'suspended': _sessionsSuspended,
        'closed': _sessionsClosed,
      },
      'reconnections': _reconnections,
      'messages': {'received': _messagesReceived, 'sent': _messagesSent},
      'errors': _errors,
      'rooms': {'joins': _roomJoins, 'leaves': _roomLeaves},
      'events': _eventCounts,
    };
  }

  @override
  String toString() =>
      'InMemoryMetrics(active: $activeConnections, msgs: $_messagesReceived)';
}

/// Métricas nulas (noop) para quando não precisar de métricas.
class NoopMetrics extends WsMetrics {
  const NoopMetrics();

  @override
  void onConnectionOpened() {}

  @override
  void onConnectionClosed() {}

  @override
  void onSessionCreated() {}

  @override
  void onSessionSuspended() {}

  @override
  void onSessionClosed() {}

  @override
  void onReconnection() {}

  @override
  void onMessageReceived(String event) {}

  @override
  void onMessageSent(String event) {}

  @override
  void onError(Object error) {}

  @override
  void onRoomJoined(String roomId) {}

  @override
  void onRoomLeft(String roomId) {}
}
