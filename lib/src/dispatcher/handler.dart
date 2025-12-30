import '../connection/connection.dart';
import '../protocol/message.dart';
import '../session/session.dart';

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

  WsContext({
    required this.session,
    required this.connection,
    required this.message,
  });

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

  /// Envia resposta para o cliente
  void send(WsMessage response) {
    connection.send(response);
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
typedef WsHandler = Future<WsMessage?> Function(WsContext context);

/// Middleware para pipeline
typedef WsMiddleware = Future<bool> Function(WsContext context);
