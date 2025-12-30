import '../connection/connection.dart';

/// Estado da sessão
enum WsSessionState {
  /// Sessão ativa com conexão funcional
  active,

  /// Sessão suspensa (conexão caiu, aguardando reconexão)
  suspended,

  /// Sessão encerrada permanentemente
  closed,
}

/// Sessão WebSocket.
///
/// Representa uma sessão lógica do usuário, independente da conexão física.
/// Uma sessão pode sobreviver a múltiplas conexões (reconexão).
///
/// Regras:
/// - Sessão sobrevive à queda de conexão
/// - Sessão é única por usuário/dispositivo
/// - Uma sessão = uma conexão ativa no máximo
class WsSession {
  /// ID único da sessão
  final String sessionId;

  /// ID do usuário (após autenticação)
  String? _userId;

  /// Conexão atual (pode mudar em reconexão)
  WsConnection? _connection;

  /// Estado atual da sessão
  WsSessionState _state = WsSessionState.active;

  /// Metadados customizáveis da sessão
  final Map<String, dynamic> metadata = {};

  /// Timestamp de criação
  final DateTime createdAt = DateTime.now();

  /// Timestamp da última atividade
  DateTime _lastActivityAt = DateTime.now();

  /// Timestamp da última suspensão
  DateTime? _suspendedAt;

  /// Salas que esta sessão pertence
  final Set<String> _rooms = {};

  WsSession({required this.sessionId, String? userId, WsConnection? connection})
    : _userId = userId,
      _connection = connection {
    // Associa conexão à sessão se fornecida
    connection?.attachSession(sessionId);
  }

  /// ID do usuário autenticado
  String? get userId => _userId;

  /// Conexão atual
  WsConnection? get connection => _connection;

  /// Estado atual
  WsSessionState get state => _state;

  /// Se a sessão está ativa
  bool get isActive => _state == WsSessionState.active;

  /// Se a sessão está suspensa
  bool get isSuspended => _state == WsSessionState.suspended;

  /// Se a sessão está fechada
  bool get isClosed => _state == WsSessionState.closed;

  /// Se tem conexão ativa
  bool get hasConnection => _connection != null && _connection!.isActive;

  /// Última atividade
  DateTime get lastActivityAt => _lastActivityAt;

  /// Quando foi suspensa
  DateTime? get suspendedAt => _suspendedAt;

  /// Salas que a sessão pertence
  Set<String> get rooms => Set.unmodifiable(_rooms);

  /// Define o usuário (após auth)
  void setUserId(String userId) {
    _userId = userId;
    _updateActivity();
  }

  /// Atualiza conexão (reconexão)
  void updateConnection(WsConnection newConnection) {
    // Desassocia conexão antiga
    _connection?.detachSession();

    // Associa nova conexão
    _connection = newConnection;
    newConnection.attachSession(sessionId);

    // Reativa sessão se estava suspensa
    if (_state == WsSessionState.suspended) {
      _state = WsSessionState.active;
      _suspendedAt = null;
    }

    _updateActivity();
  }

  /// Suspende a sessão (queda de conexão detectada)
  void suspend() {
    if (_state == WsSessionState.closed) return;

    _state = WsSessionState.suspended;
    _suspendedAt = DateTime.now();
    _connection?.detachSession();
    _connection = null;
  }

  /// Fecha a sessão permanentemente
  Future<void> close([int? closeCode, String? reason]) async {
    if (_state == WsSessionState.closed) return;

    _state = WsSessionState.closed;

    // Fecha conexão se existir
    if (_connection != null) {
      await _connection!.close(closeCode, reason);
      _connection = null;
    }

    // Limpa salas
    _rooms.clear();
  }

  /// Adiciona sessão a uma sala
  void joinRoom(String roomId) {
    _rooms.add(roomId);
    _updateActivity();
  }

  /// Remove sessão de uma sala
  void leaveRoom(String roomId) {
    _rooms.remove(roomId);
    _updateActivity();
  }

  /// Atualiza timestamp de atividade
  void _updateActivity() {
    _lastActivityAt = DateTime.now();
  }

  /// Atualiza atividade (público para heartbeat)
  void touch() => _updateActivity();

  /// Duração desde a suspensão
  Duration? get suspendedDuration {
    if (_suspendedAt == null) return null;
    return DateTime.now().difference(_suspendedAt!);
  }

  /// Duração total da sessão
  Duration get duration => DateTime.now().difference(createdAt);

  @override
  String toString() => 'WsSession($sessionId, state: $_state, user: $_userId)';
}
