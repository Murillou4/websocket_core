## 1.2.1

- **Documentation**:
  - Updated README.md with improved examples for Auto-Reply and RPC.
  - Fixed installation version instructions.

## 1.2.0

- **Major DX Improvements**:
  - **Request-Response (RPC) Pattern**: Added `client.request()` method that returns a `Future`. Clients can now await responses from the server, behaving like a standard HTTP call but over the persistent WebSocket connection.
  - **Auto-Reply Handler**: Server handlers can now return `Future<dynamic>` (e.g., a `Map` or `List`). If a value is returned, the server automatically sends it back to the client as a response. This eliminates the need to manually construct `WsMessage` for simple replies.
  - **Controllers**: Introduced `WsController` abstract class and `server.registerController()` to better organize route logic in larger applications.

- **Client**:
  - Added `_pendingRequests` management to `WsClient`.
  - Added internal `UuidGenerator` for correlation IDs in requests.
  - Updated `WsClient` to automatically match responses using `correlationId`.

- **Server**:
  - Updated `WsHandler` typedef to allow `dynamic` return types.
  - Updated `WsDispatcher` to process return values and automatically reply to the client using the incoming message's `correlationId`.

- **Documentation**:
  - Added **Lifecycle Diagram** using MermaidJS to visualize Session vs Connection.
  - Added **Deployment Guide** for Nginx and Docker.
  - Added **Error Codes** reference table.
  - Updated Cookbook with RPC and Controller examples.

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