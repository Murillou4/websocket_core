## 1.1.0

- **New Features**:
  - **Detached Mode**: `start(bindServer: false)` allows using `WsServer` with external HTTP servers (like `shelf` or `dart:io`).
  - Added `handleRequest(HttpRequest)` to manually process WebSocket upgrades.

## 1.0.0

- Initial release of **websocket_core**.
- **Core Features**:
  - Pure `dart:io` WebSocket transport (zero external dependencies).
  - Explicit connection and session management (`Session > Connection` model).
  - Protocol versioning support.
  - Logical rooms system tracking sessions instead of sockets.
  - Pluggable authentication interface.
  - Configurable Heartbeat (ping/pong) and timeout detection.
  - Robust reconnection handling with state preservation.
  - Event Dispatcher with middleware support.
  - **Rate Limiting** middleware for abuse protection.
  - Typed exceptions for better error handling.
  - Interfaces for scalability (Pub/Sub and Metrics logic).
