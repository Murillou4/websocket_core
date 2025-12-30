import '../session/session.dart';

/// Tipo de evento de lifecycle
enum LifecycleEventType {
  /// Conexão aberta
  connectionOpened,

  /// Conexão fechada
  connectionClosed,

  /// Sessão criada
  sessionCreated,

  /// Sessão suspensa
  sessionSuspended,

  /// Sessão restaurada (reconexão)
  sessionRestored,

  /// Sessão fechada
  sessionClosed,

  /// Entrada em sala
  roomJoined,

  /// Saída de sala
  roomLeft,

  /// Erro
  error,
}

/// Evento de lifecycle
class LifecycleEvent {
  /// Tipo do evento
  final LifecycleEventType type;

  /// ID da sessão (se aplicável)
  final String? sessionId;

  /// ID da conexão (se aplicável)
  final String? connectionId;

  /// ID do usuário (se aplicável)
  final String? userId;

  /// ID da sala (se aplicável)
  final String? roomId;

  /// Dados adicionais
  final Map<String, dynamic>? data;

  /// Timestamp do evento
  final DateTime timestamp;

  LifecycleEvent({
    required this.type,
    this.sessionId,
    this.connectionId,
    this.userId,
    this.roomId,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Cria evento de sessão
  factory LifecycleEvent.fromSession(
    LifecycleEventType type,
    WsSession session, {
    Map<String, dynamic>? data,
  }) {
    return LifecycleEvent(
      type: type,
      sessionId: session.sessionId,
      connectionId: session.connection?.connectionId,
      userId: session.userId,
      data: data,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('LifecycleEvent(${type.name}');
    if (sessionId != null) buffer.write(', session: $sessionId');
    if (userId != null) buffer.write(', user: $userId');
    if (roomId != null) buffer.write(', room: $roomId');
    buffer.write(')');
    return buffer.toString();
  }
}

/// Interface para listener de eventos de lifecycle
typedef LifecycleListener = void Function(LifecycleEvent event);

/// Emitter de eventos de lifecycle
class LifecycleEventEmitter {
  final List<LifecycleListener> _listeners = [];

  /// Adiciona listener
  void addListener(LifecycleListener listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(LifecycleListener listener) {
    _listeners.remove(listener);
  }

  /// Emite evento
  void emit(LifecycleEvent event) {
    for (final listener in _listeners) {
      try {
        listener(event);
      } catch (_) {
        // Ignora erros de listeners
      }
    }
  }

  /// Limpa listeners
  void clear() {
    _listeners.clear();
  }
}
