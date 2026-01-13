import 'dart:io';
import 'package:websocket_core/websocket_core.dart';

/// Exemplo de cliente WebSocket
///
/// Execute com: dart run example/client_example.dart
/// (Certifique-se de que o servidor está rodando)
void main() async {
  final client = WsClient('ws://localhost:8080/ws');

  // Monitora conexão
  client.onConnectionChanged.listen((connected) {
    print(connected ? '✅ Conectado!' : '❌ Desconectado');
    if (connected) {
      _startChat(client);
    }
  });

  // Escuta mensagens
  client.on('chat.message', (data) {
    print('[CHAT] ${data['userId']}: ${data['text']}');
  });

  client.on('room.joined', (data) {
    print('Entrou na sala: ${data['roomId']} (${data['members']} membros)');
  });

  client.on('chat.message.ack', (data) {
    print('Mensagem enviada com sucesso!');
  });
  
  // Handler de erro do sistema
  client.on('sys.error', (data) {
    print('ERRO DO SERVIDOR: ${data['message']}');
  });

  print('Tentando conectar...');
  await client.connect();

  // Mantém processo vivo
  await ProcessSignal.sigint.watch().first;
  client.dispose();
}

void _startChat(WsClient client) async {
  final roomId = 'geral';

  // Entra na sala
  print('Entrando na sala $roomId...');
  client.send('room.join', {'roomId': roomId});

  // Teste Request-Response
  try {
    print('Testando Request-Response (RPC)...');
    final response = await client.request('util.echo', {'msg': 'Hello RPC'});
    print('Resposta do RPC: $response');
  } catch (e) {
    print('Erro no request: $e');
  }

  // Aguarda um pouco e manda mensagem
  await Future.delayed(Duration(seconds: 1));
  
  print('Enviando mensagem...');
  client.send('chat.message', {
    'roomId': roomId,
    'text': 'Olá do Dart Client!',
  });

  // Simula interação contínua
  int count = 0;
  while (client.isConnected) {
    await Future.delayed(Duration(seconds: 5));
    count++;
    client.send('chat.message', {
      'roomId': roomId,
      'text': 'Mensagem automática #$count',
    });
  }
}
