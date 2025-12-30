import 'dart:io';
import 'package:websocket_core/websocket_core.dart';

/// Exemplo de integração com servidor HTTP existente.
///
/// Isso demonstra como usar o [WsServer] apenas para gerenciar a lógica WebSocket,
/// delegando o servidor HTTP para outro código (como shelf, dart:io puro, etc).
void main() async {
  // 1. Configura o WsServer
  // Note que definimos a porta, mas ela será ignorada para bind
  // pois usaremos 'bindServer: false'
  final wsServer = WsServer(config: WsServerConfig(port: 8080, path: '/ws'));

  // 2. Registra handlers do WebSocket
  wsServer.on('chat.message', (context) async {
    print('[WS] Received message: ${context.payload}');

    // Echo
    context.send(
      WsMessage(
        version: '1.0',
        event: 'chat.reply',
        payload: {'received': context.payload},
      ),
    );
    return null;
  });

  // 3. Inicia o WsServer em modo "detached" (sem servidor HTTP próprio)
  await wsServer.start(bindServer: false);
  print('WebSocket Core running in detached mode');

  // 4. Inicia seu servidor HTTP externo (ex: shelf, dart:io)
  // Aqui simulamos um servidor web comum que tem outras rotas
  final httpServer = await HttpServer.bind('localhost', 3000);
  print('Main HTTP Server running on http://localhost:3000');

  httpServer.listen((request) {
    if (request.uri.path == '/ws') {
      // 5. Encaminha requests do caminho WebSocket para o WsServer
      wsServer.handleRequest(request);
    } else {
      // Outras rotas da sua aplicação
      request.response
        ..headers.contentType = ContentType.html
        ..write('<h1>Server Running</h1><p>Connect to WebSocket at /ws</p>')
        ..close();
    }
  });
}
