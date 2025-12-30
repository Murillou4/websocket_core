import '../session/session.dart';

/// Callback quando uma sessão entra/sai de uma sala
typedef RoomCallback = void Function(WsRoom room, WsSession session);

/// Sala lógica WebSocket.
///
/// Responsabilidades:
/// - Manter set de sessões (não sockets!)
/// - Broadcast para membros
///
/// Regra importante:
/// - Sala conhece SESSÕES, não conexões
/// - Isso evita bugs clássicos de reconexão
class WsRoom {
  /// ID único da sala
  final String roomId;

  /// Set de IDs de sessões na sala
  final Set<String> _sessionIds = {};

  /// Metadados da sala
  final Map<String, dynamic> metadata = {};

  /// Timestamp de criação
  final DateTime createdAt = DateTime.now();

  /// Máximo de membros (0 = ilimitado)
  final int maxMembers;

  WsRoom({required this.roomId, this.maxMembers = 0});

  /// Número de membros
  int get memberCount => _sessionIds.length;

  /// Se a sala está vazia
  bool get isEmpty => _sessionIds.isEmpty;

  /// Se a sala está cheia
  bool get isFull => maxMembers > 0 && _sessionIds.length >= maxMembers;

  /// IDs das sessões na sala
  Set<String> get sessionIds => Set.unmodifiable(_sessionIds);

  /// Adiciona uma sessão à sala
  bool addSession(String sessionId) {
    if (isFull) return false;
    return _sessionIds.add(sessionId);
  }

  /// Remove uma sessão da sala
  bool removeSession(String sessionId) {
    return _sessionIds.remove(sessionId);
  }

  /// Verifica se uma sessão está na sala
  bool hasSession(String sessionId) {
    return _sessionIds.contains(sessionId);
  }

  @override
  String toString() => 'WsRoom($roomId, members: $memberCount)';
}
