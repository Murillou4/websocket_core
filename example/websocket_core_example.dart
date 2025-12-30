import 'package:websocket_core/websocket_core.dart';

/// Exemplo básico de servidor WebSocket
///
/// Execute com: dart run example/server_example.dart
void main() async {
  // Configura servidor
  final server = WsServer(
    config: const WsServerConfig(
      host: 'localhost',
      port: 8080,
      path: '/ws',
      heartbeatInterval: Duration(seconds: 30),
    ),
    // Opcional: métricas em memória para debug
    metrics: InMemoryMetrics(),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  // Handler para entrar em sala
  server.on('room.join', (context) async {
    final roomId = context.payload['roomId'] as String?;
    if (roomId == null) {
      context.error(code: 1009, message: 'roomId is required');
      return null;
    }

    server.rooms.join(roomId, context.session);

    print('Session ${context.sessionId} joined room $roomId');

    context.reply(
      event: 'room.joined',
      payload: {
        'roomId': roomId,
        'members': server.rooms.getSessionsInRoom(roomId).length,
      },
    );

    // Notifica outros na sala
    server.broadcastToRoom(
      roomId,
      WsMessage(
        version: '1.0',
        event: 'room.user_joined',
        payload: {
          'userId': context.userId ?? context.sessionId,
          'roomId': roomId,
        },
      ),
      excludeSessionId: context.sessionId,
    );

    return null;
  });

  // Handler para sair de sala
  server.on('room.leave', (context) async {
    final roomId = context.payload['roomId'] as String?;
    if (roomId == null) {
      context.error(code: 1009, message: 'roomId is required');
      return null;
    }

    server.rooms.leave(roomId, context.session);

    print('Session ${context.sessionId} left room $roomId');

    context.reply(event: 'room.left', payload: {'roomId': roomId});

    // Notifica outros na sala
    server.broadcastToRoom(
      roomId,
      WsMessage(
        version: '1.0',
        event: 'room.user_left',
        payload: {
          'userId': context.userId ?? context.sessionId,
          'roomId': roomId,
        },
      ),
    );

    return null;
  });

  // Handler para mensagem de chat
  server.on('chat.message', (context) async {
    final roomId = context.payload['roomId'] as String?;
    final text = context.payload['text'] as String?;

    if (roomId == null || text == null) {
      context.error(code: 1009, message: 'roomId and text are required');
      return null;
    }

    print('Chat message in $roomId: $text');

    // Broadcast para a sala
    final sentCount = server.broadcastToRoom(
      roomId,
      WsMessage(
        version: '1.0',
        event: 'chat.message',
        payload: {
          'roomId': roomId,
          'userId': context.userId ?? context.sessionId,
          'text': text,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ),
      excludeSessionId: context.sessionId,
    );

    // Confirma envio
    context.reply(event: 'chat.message.ack', payload: {'delivered': sentCount});

    return null;
  });

  // Handler para listar salas do usuário
  server.on('room.list', (context) async {
    final rooms = context.session.rooms.toList();

    context.reply(event: 'room.list', payload: {'rooms': rooms});

    return null;
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MIDDLEWARE
  // ═══════════════════════════════════════════════════════════════════════════

  // Middleware de logging
  server.use((context) async {
    print('[${DateTime.now()}] ${context.event} from ${context.sessionId}');
    return true; // continua
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // START
  // ═══════════════════════════════════════════════════════════════════════════

  await server.start();

  print('');
  print('╔════════════════════════════════════════════════════╗');
  print('║  WebSocket Server running on ws://localhost:8080/ws ║');
  print('╚════════════════════════════════════════════════════╝');
  print('');
  print('Test with websocat:');
  print('  websocat ws://localhost:8080/ws');
  print('');
  print('Send messages like:');
  print('  {"e":"room.join","p":{"roomId":"test"}}');
  print('  {"e":"chat.message","p":{"roomId":"test","text":"Hello!"}}');
  print('');
}
