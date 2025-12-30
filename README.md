# websocket_core

**Core WebSocket Backend para Dart — explícito, performático e sem abstrações mágicas.**

[![Dart](https://img.shields.io/badge/Dart-3.10+-blue)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## O que é

Um **core WebSocket backend** em Dart puro:

- ✅ Transporte WebSocket **puro** (`dart:io`)
- ✅ Controle explícito de sessão, reconexão, salas e protocolo
- ✅ Backend-only
- ✅ **Zero dependências externas**

## O que NÃO é

- ❌ Não é framework web
- ❌ Não é ORM
- ❌ Não é solução mágica de escala
- ❌ Não esconde lógica crítica

## Quando usar

- ✅ Você precisa de controle total sobre WebSocket
- ✅ Você entende a diferença entre sessão e conexão
- ✅ Você quer protocolo explícito
- ✅ Você vai implementar sua própria autenticação

## Quando NÃO usar

- ❌ Você quer algo que "just works" sem entender
- ❌ Você precisa de escala automática sem mensageria
- ❌ Você quer Socket.IO behavior

---

## Conceitos Principais

### 1. Sessão > Conexão

```
Conexão = socket físico (pode cair)
Sessão  = identidade lógica (sobrevive à queda)
```

Uma sessão pode ter múltiplas conexões ao longo do tempo (reconexão).

### 2. Protocolo Explícito

Toda mensagem tem estrutura definida:

```json
{
  "v": "1.0",          // versão do protocolo
  "e": "chat.message", // evento
  "p": {},             // payload
  "c": "abc123",       // correlation ID (opcional)
  "t": 1703123456789   // timestamp
}
```

### 3. Autenticação Plugável

O package **não implementa** autenticação. Você implementa:

```dart
class JwtAuthenticator extends WsAuthenticator {
  @override
  Future<AuthResult> authenticate(WsConnection conn, String? token) async {
    if (token == null) return AuthResult.failure(error: 'Token required');
    
    final payload = verifyJwt(token); // sua lógica
    return AuthResult.success(userId: payload['sub']);
  }
}
```

### 4. Salas por Sessão

Salas rastreiam **sessões**, não conexões:

```dart
server.rooms.join('room-123', session);
server.rooms.broadcast('room-123', message);
```

Se a conexão cair e reconectar, a sessão continua na sala.

---

## Quick Start

### Servidor básico

```dart
import 'package:websocket_core/websocket_core.dart';

void main() async {
  final server = WsServer(
    config: WsServerConfig(
      host: 'localhost',
      port: 8080,
      path: '/ws',
    ),
  );

  // Handler para mensagem de chat
  server.on('chat.message', (context) async {
    final roomId = context.payload['roomId'] as String;
    final text = context.payload['text'] as String;

    // Broadcast para a sala (exceto quem enviou)
    server.broadcastToRoom(
      roomId,
      WsMessage(
        version: '1.0',
        event: 'chat.message',
        payload: {
          'userId': context.userId,
          'text': text,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ),
      excludeSessionId: context.sessionId,
    );

    // Confirma recebimento
    context.reply(event: 'chat.message.ack', payload: {'status': 'sent'});
    return null;
  });

  // Handler para entrar em sala
  server.on('room.join', (context) async {
    final roomId = context.payload['roomId'] as String;
    server.rooms.join(roomId, context.session);

    context.reply(event: 'room.joined', payload: {'roomId': roomId});
    return null;
  });

  await server.start();
  print('Server running on ws://localhost:8080/ws');
}
```

### Com autenticação

```dart
final server = WsServer(
  config: WsServerConfig(
    port: 8080,
    requireAuth: true,
  ),
  authenticator: CallbackAuthenticator((conn, token) async {
    if (token == null) {
      return AuthResult.failure(error: 'Token required');
    }
    
    // Sua lógica de validação
    final userId = await validateToken(token);
    if (userId == null) {
      return AuthResult.failure(error: 'Invalid token');
    }
    
    return AuthResult.success(userId: userId);
  }),
);
```

---

## Fluxo de Conexão

```
Cliente                           Servidor
   |                                  |
   |------ HTTP Upgrade ------------→|
   |                                  |
   |←----- sys.session.created ------|  (sessionId, userId)
   |                                  |
   |------ chat.message -----------→|
   |                                  |
   |←----- chat.message.ack --------|
   |                                  |
```

## Fluxo de Reconexão

```
Cliente                           Servidor
   |                                  |
   |  (conexão cai)                   |
   |                                  |  sessão suspensa
   |                                  |
   |------ HTTP Upgrade ------------→|
   |------ sys.reconnect.request --→|  (sessionId)
   |                                  |
   |←----- sys.session.restored ----|  (sessão restaurada)
   |                                  |
```

---

## Escala

### Single Server

Funciona out-of-the-box. Salas e broadcast em memória.

### Múltiplos Servidores

WebSocket **não escala sozinho**. Você precisa de mensageria:

```dart
// Implemente WsPubSub para seu broker
class RedisPubSub implements WsPubSub {
  @override
  Future<void> publish(String channel, WsMessage message) async {
    await redis.publish(channel, message.toJson());
  }

  @override
  Future<Stream<WsMessage>> subscribe(String channel) async {
    return redis.subscribe(channel).map((data) => WsMessage.fromJson(data));
  }
}

// Use no servidor
final server = WsServer(
  pubSub: RedisPubSub(),
);
```

---

## API Reference

### WsServer

```dart
// Configuração
final server = WsServer(
  config: WsServerConfig(...),
  authenticator: MyAuthenticator(),
  pubSub: MyPubSub(),
  metrics: InMemoryMetrics(),
);

// Handlers
server.on('event', handler);
server.on('event', handler, requiresAuth: true);

// Middleware
server.use((context) async {
  // logging, rate limiting, etc
  return true; // continue
});

// Lifecycle
await server.start();
await server.stop();

// Broadcast
server.broadcast(message);
server.broadcastToRoom(roomId, message);
```

### WsContext

```dart
server.on('my.event', (context) async {
  context.sessionId;   // ID da sessão
  context.userId;      // ID do usuário (se autenticado)
  context.event;       // Nome do evento
  context.payload;     // Payload da mensagem
  
  context.reply(event: 'response', payload: {...});
  context.error(code: 1001, message: 'Error');
  
  return null;
});
```

### Salas

```dart
server.rooms.join(roomId, session);
server.rooms.leave(roomId, session);
server.rooms.broadcast(roomId, message);
server.rooms.getSessionsInRoom(roomId);
```

---

## Protocolo de Mensagens

### Formato

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `v` | string | sim | Versão do protocolo |
| `e` | string | sim | Nome do evento |
| `p` | object | não | Payload |
| `c` | string | não | Correlation ID |
| `t` | int | não | Timestamp (ms) |

### Eventos do Sistema

| Evento | Direção | Descrição |
|--------|---------|-----------|
| `sys.session.created` | S→C | Sessão criada |
| `sys.session.restored` | S→C | Sessão restaurada |
| `sys.ping` | S→C | Heartbeat ping |
| `sys.pong` | C→S | Heartbeat pong |
| `sys.error` | S→C | Erro |

---

## License

MIT
