/// WebSocket Core - Backend WebSocket package for Dart
///
/// A pure WebSocket backend core with explicit protocol, session management,
/// reconnection, rooms and zero external dependencies.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:websocket_core/websocket_core.dart';
///
/// void main() async {
///   final server = WsServer(
///     config: WsServerConfig(port: 8080),
///   );
///
///   // Register event handlers
///   server.on('chat.message', (context) async {
///     // Broadcast to room
///     server.rooms.broadcast(
///       context.payload['roomId'],
///       context.message,
///       excludeSessionId: context.sessionId,
///     );
///     return null;
///   });
///
///   await server.start();
/// }
/// ```
///
/// ## Core Concepts
///
/// - **Session > Connection**: Sessions survive connection drops
/// - **Explicit Protocol**: No implicit message formats
/// - **Pluggable Auth**: Implement your own authentication
/// - **Rooms by Session**: Rooms track sessions, not connections
library;

// ══════════════════════════════════════════════════════════════════════════════
// PROTOCOL
// ══════════════════════════════════════════════════════════════════════════════
export 'src/protocol/message.dart';
export 'src/protocol/protocol.dart';
export 'src/protocol/events.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CONNECTION
// ══════════════════════════════════════════════════════════════════════════════
export 'src/connection/connection.dart';
export 'src/connection/connection_manager.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SESSION
// ══════════════════════════════════════════════════════════════════════════════
export 'src/session/session.dart';
export 'src/session/session_manager.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AUTH
// ══════════════════════════════════════════════════════════════════════════════
export 'src/auth/authenticator.dart';

// ══════════════════════════════════════════════════════════════════════════════
// HEARTBEAT
// ══════════════════════════════════════════════════════════════════════════════
export 'src/heartbeat/heartbeat_manager.dart';

// ══════════════════════════════════════════════════════════════════════════════
// RECONNECTION
// ══════════════════════════════════════════════════════════════════════════════
export 'src/reconnection/reconnection_handler.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ROOM
// ══════════════════════════════════════════════════════════════════════════════
export 'src/room/room.dart';
export 'src/room/room_manager.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DISPATCHER
// ══════════════════════════════════════════════════════════════════════════════
export 'src/dispatcher/handler.dart';
export 'src/dispatcher/dispatcher.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SERVER
// ══════════════════════════════════════════════════════════════════════════════
export 'src/server/config.dart';
export 'src/server/server.dart';
export 'src/server/controller.dart';

// ══════════════════════════════════════════════════════════════════════════════
// OBSERVABILITY
// ══════════════════════════════════════════════════════════════════════════════
export 'src/observability/metrics.dart';
export 'src/observability/lifecycle_events.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ADAPTERS
// ══════════════════════════════════════════════════════════════════════════════
export 'src/adapters/pubsub.dart';
export 'src/adapters/event_bus.dart';

// ══════════════════════════════════════════════════════════════════════════════
// UTILS
// ══════════════════════════════════════════════════════════════════════════════
export 'src/utils/id_generator.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MIDDLEWARE
// ══════════════════════════════════════════════════════════════════════════════
export 'src/middleware/rate_limiter.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EXCEPTIONS
// ══════════════════════════════════════════════════════════════════════════════
export 'src/exceptions/exceptions.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CLIENT
// ══════════════════════════════════════════════════════════════════════════════
export 'src/client/client.dart';
