import 'package:websocket_core/websocket_core.dart';

/// Exemplo moderno de servidor WebSocket usando as novas features
///
/// Execute com: dart run example/websocket_core_example.dart
void main() async {
  // 1. Configuração simplificada com Factory .dev
  final server = WsServer(
    config: WsServerConfig.dev(port: 8080),
    metrics: InMemoryMetrics(),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  // Handler para entrar em sala (Com Syntactic Sugar)
  server.on('room.join', (ctx) async {
    // Validação implícita (se schema falhar, nem chega aqui)
    final roomId = ctx.payload['roomId'];

    server.rooms.join(roomId, ctx.session);

    print('Session ${ctx.sessionId} joined room $roomId');

    // Resposta direta
    ctx.emit('room.joined', {
      'roomId': roomId,
      'members': server.rooms.getSessionsInRoom(roomId).length,
    });

    // Broadcast simplificado
    ctx.broadcastToRoom(roomId, 'room.user_joined', {
      'userId': ctx.userId ?? ctx.sessionId,
      'roomId': roomId,
    });
    return null;
  }, schema: {
    // Validação Declarativa
    'roomId': (v) => v is String && v.isNotEmpty,
  });

  // Handler para sair de sala
  server.on('room.leave', (ctx) async {
    final roomId = ctx.payload['roomId'];

    server.rooms.leave(roomId, ctx.session);
    print('Session ${ctx.sessionId} left room $roomId');

    ctx.emit('room.left', {'roomId': roomId});

    ctx.broadcastToRoom(roomId, 'room.user_left', {
      'userId': ctx.userId ?? ctx.sessionId,
      'roomId': roomId,
    });
    return null;
  }, schema: {
    'roomId': (v) => v is String && v.isNotEmpty,
  });

  // Handler para mensagem de chat
  server.on('chat.message', (ctx) async {
    final roomId = ctx.payload['roomId'];
    final text = ctx.payload['text'];

    print('Chat message in $roomId: $text');

    // Broadcast
    ctx.broadcastToRoom(roomId, 'chat.message', {
      'roomId': roomId,
      'userId': ctx.userId ?? ctx.sessionId,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Confirma envio (Ack)
    ctx.emit('chat.message.ack', {'status': 'sent'});
    return null;
  }, schema: {
    'roomId': (v) => v is String && v.isNotEmpty,
    'text': (v) => v is String && v.isNotEmpty,
  });

  // Handler demonstração de Auto-Reply (DX Improvement)
  // Retorne um Map e o servidor envia a resposta automaticamente
  server.on('util.echo', (ctx) async {
    return {
        'echo': ctx.payload,
        'server_time': DateTime.now().toIso8601String(),
    };
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // START
  // ═══════════════════════════════════════════════════════════════════════════

  await server.start();

  print('');
  print('╔════════════════════════════════════════════════════╗');
  print('║  WebSocket Server running on ws://localhost:8080/ws ║');
  print('╚════════════════════════════════════════════════════╝');
  print('Use example/client_example.dart to test!');
}