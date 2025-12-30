import 'dart:async';

/// Tipo de evento do bus
typedef EventHandler<T> = void Function(T event);

/// Interface para Event Bus distribuído.
///
/// Similar a Pub/Sub, mas para eventos tipados.
/// O package NÃO implementa distribuição real.
abstract class WsEventBus {
  const WsEventBus();

  /// Emite um evento
  void emit<T>(String event, T data);

  /// Registra listener para um evento
  void on<T>(String event, EventHandler<T> handler);

  /// Remove listener
  void off<T>(String event, EventHandler<T> handler);

  /// Remove todos os listeners de um evento
  void offAll(String event);

  /// Fecha o event bus
  Future<void> close();
}

/// Event Bus local (em memória).
///
/// Útil para comunicação interna em um único servidor.
class LocalTypedEventBus implements WsEventBus {
  final Map<String, Set<Function>> _handlers = {};

  @override
  void emit<T>(String event, T data) {
    final handlers = _handlers[event];
    if (handlers == null) return;

    for (final handler in handlers.toList()) {
      try {
        (handler as EventHandler<T>)(data);
      } catch (_) {
        // Ignora erros de handlers
      }
    }
  }

  @override
  void on<T>(String event, EventHandler<T> handler) {
    _handlers.putIfAbsent(event, () => {}).add(handler);
  }

  @override
  void off<T>(String event, EventHandler<T> handler) {
    _handlers[event]?.remove(handler);
  }

  @override
  void offAll(String event) {
    _handlers.remove(event);
  }

  @override
  Future<void> close() async {
    _handlers.clear();
  }
}

/// Evento de broadcast para salas
class RoomBroadcastEvent {
  final String roomId;
  final String event;
  final Map<String, dynamic> payload;
  final String? excludeSessionId;

  const RoomBroadcastEvent({
    required this.roomId,
    required this.event,
    required this.payload,
    this.excludeSessionId,
  });
}

/// Evento de sessão
class SessionEvent {
  final String sessionId;
  final String? userId;
  final String eventType;
  final Map<String, dynamic>? data;

  const SessionEvent({
    required this.sessionId,
    this.userId,
    required this.eventType,
    this.data,
  });
}
