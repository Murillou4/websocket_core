import '../connection/connection.dart';
import '../protocol/message.dart';
import '../session/session.dart';
import '../exceptions/exceptions.dart';

/// Callback para broadcast em sala
typedef BroadcastToRoomCallback = void Function(
  String roomId,
  String event,
  Map<String, dynamic> payload, {
  String? excludeSessionId,
});

/// Contexto passado para handlers
class WsContext {
  /// Sessão do cliente
  final WsSession session;

  /// Conexão atual
  final WsConnection connection;

  /// Mensagem recebida
  final WsMessage message;

  /// Metadados adicionais do contexto
  final Map<String, dynamic> extras = {};

  /// Callback para broadcast em sala (injetado pelo servidor)
  final BroadcastToRoomCallback? _broadcastToRoom;

  WsContext({
    required this.session,
    required this.connection,
    required this.message,
    BroadcastToRoomCallback? broadcastToRoom,
  }) : _broadcastToRoom = broadcastToRoom;

  /// ID da sessão
  String get sessionId => session.sessionId;

  /// ID do usuário (se autenticado)
  String? get userId => session.userId;

  /// Evento da mensagem
  String get event => message.event;

  /// Payload da mensagem
  Map<String, dynamic> get payload => message.payload;

  /// Correlation ID para resposta
  String? get correlationId => message.correlationId;

  /// Envia resposta para o cliente (Raw)
  void send(WsMessage response) {
    connection.send(response);
  }

  /// Envia mensagem diretamente para o cliente (Syntactic Sugar)
  void emit(String event, [Map<String, dynamic>? data]) {
    connection.send(
      WsMessage(
        version: message.version,
        event: event,
        payload: data ?? {},
      ),
    );
  }

  /// Envia broadcast para uma sala (Syntactic Sugar)
  void broadcastToRoom(String roomId, String event, [Map<String, dynamic>? data]) {
    if (_broadcastToRoom != null) {
      _broadcastToRoom(
        roomId,
        event,
        data ?? {},
        excludeSessionId: session.sessionId,
      );
    } else {
      throw StateError('Broadcast capability not available in this context');
    }
  }

  /// Helper de Payload Tipado
  /// Converte o payload para um objeto tipado usando uma factory function
  T bind<T>(T Function(Map<String, dynamic>) fromJson) {
    try {
      return fromJson(payload);
    } catch (e) {
      throw WsValidationException('Invalid payload structure for $T: $e');
    }
  }

  /// Envia resposta com mesmo correlationId
  void reply({required String event, Map<String, dynamic> payload = const {}}) {
    final response = WsMessage(
      version: message.version,
      event: event,
      payload: payload,
      correlationId: correlationId,
    );
    connection.send(response);
  }

  /// Envia erro
  void error({
    required int code,
    required String message,
    Map<String, dynamic>? details,
  }) {
    final response = WsMessage(
      version: this.message.version,
      event: 'sys.error',
      payload: {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      },
      correlationId: correlationId,
    );
    connection.send(response);
  }
}

/// Tipo de handler de eventos
typedef WsHandler = Future<dynamic> Function(WsContext context);

/// Middleware para pipeline
typedef WsMiddleware = Future<bool> Function(WsContext context);
