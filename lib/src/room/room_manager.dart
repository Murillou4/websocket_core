import '../protocol/message.dart';
import '../session/session.dart';
import '../session/session_manager.dart';
import 'room.dart';

/// Callback para eventos de sala
typedef RoomEventCallback = void Function(WsRoom room, WsSession session);

/// Gerenciador de salas.
///
/// Responsabilidades:
/// - Criar/buscar/deletar salas
/// - Join/leave de sessões
/// - Broadcast para sala
class WsRoomManager {
  /// Gerenciador de sessões para buscar sessões
  final WsSessionManager _sessionManager;

  /// Mapa de salas
  final Map<String, WsRoom> _rooms = {};

  /// Callbacks de entrada em sala
  final List<RoomEventCallback> _onJoinCallbacks = [];

  /// Callbacks de saída de sala
  final List<RoomEventCallback> _onLeaveCallbacks = [];

  /// Se deve criar sala automaticamente no join
  final bool autoCreate;

  /// Se deve deletar sala vazia automaticamente
  final bool autoDelete;

  WsRoomManager({
    required WsSessionManager sessionManager,
    this.autoCreate = true,
    this.autoDelete = true,
  }) : _sessionManager = sessionManager;

  /// Número de salas
  int get roomCount => _rooms.length;

  /// IDs das salas
  Iterable<String> get roomIds => _rooms.keys;

  /// Lista de salas
  Iterable<WsRoom> get rooms => _rooms.values;

  /// Cria uma sala
  WsRoom createRoom(String roomId, {int maxMembers = 0}) {
    if (_rooms.containsKey(roomId)) {
      return _rooms[roomId]!;
    }

    final room = WsRoom(roomId: roomId, maxMembers: maxMembers);

    _rooms[roomId] = room;
    return room;
  }

  /// Busca uma sala
  WsRoom? getRoom(String roomId) {
    return _rooms[roomId];
  }

  /// Verifica se uma sala existe
  bool hasRoom(String roomId) {
    return _rooms.containsKey(roomId);
  }

  /// Deleta uma sala
  bool deleteRoom(String roomId) {
    final room = _rooms.remove(roomId);
    if (room != null) {
      // Remove sessões da sala
      for (final sessionId in room.sessionIds.toList()) {
        final session = _sessionManager.getSession(sessionId);
        session?.leaveRoom(roomId);
      }
      return true;
    }
    return false;
  }

  /// Adiciona sessão a uma sala
  bool join(String roomId, WsSession session) {
    WsRoom? room = _rooms[roomId];

    // Auto-cria sala se configurado
    if (room == null) {
      if (!autoCreate) return false;
      room = createRoom(roomId);
    }

    // Tenta adicionar
    final added = room.addSession(session.sessionId);
    if (added) {
      session.joinRoom(roomId);

      // Notifica callbacks
      for (final callback in _onJoinCallbacks) {
        callback(room, session);
      }
    }

    return added;
  }

  /// Remove sessão de uma sala
  bool leave(String roomId, WsSession session) {
    final room = _rooms[roomId];
    if (room == null) return false;

    final removed = room.removeSession(session.sessionId);
    if (removed) {
      session.leaveRoom(roomId);

      // Notifica callbacks
      for (final callback in _onLeaveCallbacks) {
        callback(room, session);
      }

      // Auto-deleta sala vazia se configurado
      if (autoDelete && room.isEmpty) {
        _rooms.remove(roomId);
      }
    }

    return removed;
  }

  /// Remove sessão de todas as salas
  void leaveAll(WsSession session) {
    final roomIds = session.rooms.toList();
    for (final roomId in roomIds) {
      leave(roomId, session);
    }
  }

  /// Broadcast para uma sala
  ///
  /// Retorna número de sessões que receberam a mensagem
  int broadcast(String roomId, WsMessage message, {String? excludeSessionId}) {
    final room = _rooms[roomId];
    if (room == null) return 0;

    int sent = 0;

    for (final sessionId in room.sessionIds) {
      // Pula sessão excluída
      if (sessionId == excludeSessionId) continue;

      final session = _sessionManager.getSession(sessionId);
      if (session == null || !session.hasConnection) continue;

      try {
        session.connection!.send(message);
        sent++;
      } catch (_) {
        // Ignora erros de envio individual
      }
    }

    return sent;
  }

  /// Broadcast para múltiplas salas
  Map<String, int> broadcastToRooms(
    Set<String> roomIds,
    WsMessage message, {
    String? excludeSessionId,
  }) {
    final results = <String, int>{};
    for (final roomId in roomIds) {
      results[roomId] = broadcast(
        roomId,
        message,
        excludeSessionId: excludeSessionId,
      );
    }
    return results;
  }

  /// Lista sessões de uma sala
  List<WsSession> getSessionsInRoom(String roomId) {
    final room = _rooms[roomId];
    if (room == null) return [];

    return room.sessionIds
        .map((id) => _sessionManager.getSession(id))
        .whereType<WsSession>()
        .toList();
  }

  /// Registra callback de entrada em sala
  void onJoin(RoomEventCallback callback) {
    _onJoinCallbacks.add(callback);
  }

  /// Registra callback de saída de sala
  void onLeave(RoomEventCallback callback) {
    _onLeaveCallbacks.add(callback);
  }

  /// Remove callback de entrada
  void removeOnJoin(RoomEventCallback callback) {
    _onJoinCallbacks.remove(callback);
  }

  /// Remove callback de saída
  void removeOnLeave(RoomEventCallback callback) {
    _onLeaveCallbacks.remove(callback);
  }

  /// Limpa todas as salas
  void clear() {
    _rooms.clear();
  }
}
