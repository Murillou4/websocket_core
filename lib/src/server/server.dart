import 'dart:async';
import 'dart:io';

import '../auth/authenticator.dart';
import '../connection/connection.dart';
import '../connection/connection_manager.dart';
import '../dispatcher/dispatcher.dart';
import '../dispatcher/handler.dart';
import '../heartbeat/heartbeat_manager.dart';
import '../observability/metrics.dart';
import '../protocol/events.dart';
import '../protocol/message.dart';
import '../protocol/protocol.dart';
import '../reconnection/reconnection_handler.dart';
import '../room/room_manager.dart';
import '../session/session.dart';
import '../session/session_manager.dart';
import '../adapters/pubsub.dart';
import 'config.dart';

/// Estado do servidor
enum WsServerState {
  /// Servidor parado
  stopped,

  /// Servidor iniciando
  starting,

  /// Servidor rodando
  running,

  /// Servidor parando
  stopping,
}

/// Servidor WebSocket principal.
///
/// Integra todos os módulos e gerencia o ciclo de vida.
class WsServer {
  /// Configuração do servidor
  final WsServerConfig config;

  /// Autenticador plugável
  final WsAuthenticator? authenticator;

  /// Pub/Sub para escala
  final WsPubSub? pubSub;

  /// Métricas
  final WsMetrics? metrics;

  /// Protocolo
  late final WsProtocol _protocol;

  /// Gerenciador de conexões
  late final WsConnectionManager _connectionManager;

  /// Gerenciador de sessões
  late final WsSessionManager _sessionManager;

  /// Gerenciador de salas
  late final WsRoomManager _roomManager;

  /// Gerenciador de heartbeat
  late final HeartbeatManager _heartbeatManager;

  /// Handler de reconexão
  late final ReconnectionHandler _reconnectionHandler;

  /// Dispatcher de eventos
  late final WsDispatcher _dispatcher;

  /// Servidor HTTP
  HttpServer? _httpServer;

  /// Estado atual
  WsServerState _state = WsServerState.stopped;

  /// Subscriptions
  final List<StreamSubscription> _subscriptions = [];

  WsServer({
    WsServerConfig? config,
    this.authenticator,
    this.pubSub,
    this.metrics,
  }) : config = config ?? const WsServerConfig() {
    _initializeComponents();
  }

  /// Estado atual do servidor
  WsServerState get state => _state;

  /// Se o servidor está rodando
  bool get isRunning => _state == WsServerState.running;

  /// Acesso ao gerenciador de conexões
  WsConnectionManager get connections => _connectionManager;

  /// Acesso ao gerenciador de sessões
  WsSessionManager get sessions => _sessionManager;

  /// Acesso ao gerenciador de salas
  WsRoomManager get rooms => _roomManager;

  /// Acesso ao dispatcher
  WsDispatcher get dispatcher => _dispatcher;

  /// Inicializa componentes
  void _initializeComponents() {
    _protocol = WsProtocol(
      currentVersion: config.protocolVersion,
      supportedVersions: config.supportedVersions,
    );

    _connectionManager = WsConnectionManager(protocol: _protocol);

    _sessionManager = WsSessionManager(
      suspendTimeout: config.sessionSuspendTimeout,
      cleanupInterval: config.sessionCleanupInterval,
    );

    _roomManager = WsRoomManager(sessionManager: _sessionManager);

    _heartbeatManager = HeartbeatManager(
      interval: config.heartbeatInterval,
      timeout: config.heartbeatTimeout,
      protocolVersion: config.protocolVersion,
    );

    _reconnectionHandler = ReconnectionHandler(
      sessionManager: _sessionManager,
      authenticator: authenticator,
    );

    _dispatcher = WsDispatcher(defaultVersion: config.protocolVersion);

    // Configura callbacks
    _setupCallbacks();

    // Registra handlers do sistema
    _registerSystemHandlers();
  }

  /// Configura callbacks entre componentes
  void _setupCallbacks() {
    // Quando sessão é suspensa, para heartbeat
    _sessionManager.onSessionSuspended((session) {
      _heartbeatManager.stopMonitoring(session.sessionId);
      metrics?.onSessionSuspended();
    });

    // Quando sessão é fechada, remove de salas e para heartbeat
    _sessionManager.onSessionClosed((session) {
      _roomManager.leaveAll(session);
      _heartbeatManager.stopMonitoring(session.sessionId);
      metrics?.onSessionClosed();
    });

    // Quando reconecta, reinicia heartbeat
    _sessionManager.onSessionReconnected((session) {
      _heartbeatManager.monitor(session);
      metrics?.onReconnection();
    });

    // Heartbeat timeout suspende sessão
    _heartbeatManager.onTimeout = (session) {
      _sessionManager.suspendSession(session.sessionId);
    };

    // Métricas de conexão
    _connectionManager.onConnect((connection) {
      metrics?.onConnectionOpened();
    });

    _connectionManager.onDisconnect((connection) {
      metrics?.onConnectionClosed();
    });
  }

  /// Registra handlers de eventos do sistema
  void _registerSystemHandlers() {
    // Pong
    _dispatcher.on(WsEvents.pong, (context) async {
      _heartbeatManager.handlePong(context.sessionId);
      return null;
    });

    // Reconexão explícita
    _dispatcher.on('sys.reconnect.request', (context) async {
      final sessionId = context.payload['sessionId'] as String?;
      final token = context.payload['token'] as String?;

      if (sessionId == null) {
        context.error(
          code: WsErrorCodes.validationFailed,
          message: 'sessionId is required',
        );
        return null;
      }

      final result = await _reconnectionHandler.reconnect(
        newConnection: context.connection,
        sessionId: sessionId,
        token: token,
      );

      if (result.success) {
        final msg = _reconnectionHandler.createSessionRestoredMessage(
          result.session!,
        );
        context.send(msg);
      } else {
        context.error(
          code: result.errorCode ?? WsErrorCodes.sessionNotFound,
          message: result.error ?? 'Reconnection failed',
        );
      }

      return null;
    });
  }

  /// Registra handler para um evento
  void on(String event, WsHandler handler, {bool requiresAuth = false}) {
    _dispatcher.on(event, handler, requiresAuth: requiresAuth);
  }

  /// Registra middleware global
  void use(WsMiddleware middleware) {
    _dispatcher.use(middleware);
  }

  /// Inicia o servidor
  ///
  /// Se [bindServer] for true (padrão), cria um HttpServer na porta configurada.
  /// Se false, apenas inicializa os componentes internos e espera chamadas em [handleRequest].
  Future<void> start({bool bindServer = true}) async {
    if (_state != WsServerState.stopped) {
      throw StateError('Server is already running or starting');
    }

    _state = WsServerState.starting;

    try {
      // Inicia heartbeat
      _heartbeatManager.start();

      // Inicia pub/sub se configurado
      if (pubSub != null) {
        await _setupPubSub();
      }

      if (bindServer) {
        // Cria servidor HTTP
        _httpServer = await HttpServer.bind(
          config.host,
          config.port,
          shared: true,
        );

        // Escuta conexões
        _subscriptions.add(_httpServer!.listen(handleRequest));
        print('WebSocket server running on ${config.uri}');
      } else {
        print(
          'WebSocket server starting in detached mode (no HTTP server bound)',
        );
      }

      _state = WsServerState.running;
    } catch (e) {
      _state = WsServerState.stopped;
      rethrow;
    }
  }

  /// Para o servidor
  Future<void> stop() async {
    if (_state != WsServerState.running) return;

    _state = WsServerState.stopping;

    // Cancela subscriptions
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Para heartbeat
    _heartbeatManager.stop();

    // Fecha todas as sessões
    await _sessionManager.closeAll(
      WsCloseCodes.goingAway,
      'Server shutting down',
    );

    // Fecha servidor HTTP se existir
    await _httpServer?.close(force: true);
    _httpServer = null;

    // Limpa recursos
    _sessionManager.dispose();
    _heartbeatManager.dispose();

    _state = WsServerState.stopped;
    print('WebSocket server stopped');
  }

  /// Trata request HTTP
  ///
  /// Use este método se estiver usando um servidor HTTP externo (ex: shelf, dart:io raw).
  Future<void> handleRequest(HttpRequest request) async {
    if (_state != WsServerState.running) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..write('WebSocket server is not running')
        ..close();
      return;
    }

    // Verifica path
    if (request.uri.path != config.path) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found')
        ..close();
      return;
    }

    // Adiciona headers CORS se configurado
    if (config.corsHeaders != null) {
      config.corsHeaders!.forEach((key, value) {
        request.response.headers.add(key, value);
      });
    }

    // Verifica se é upgrade WebSocket
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('WebSocket upgrade required')
        ..close();
      return;
    }

    try {
      // Faz upgrade
      final socket = await WebSocketTransformer.upgrade(
        request,
        compression: config.enableCompression
            ? CompressionOptions.compressionDefault
            : CompressionOptions.compressionOff,
      );

      // Cria conexão
      final connection = _connectionManager.createConnection(socket);

      // Processa handshake
      await _handleNewConnection(connection, request);
    } catch (e) {
      print('Error upgrading WebSocket: $e');
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('WebSocket upgrade failed')
        ..close();
    }
  }

  /// Trata nova conexão
  Future<void> _handleNewConnection(
    WsConnection connection,
    HttpRequest request,
  ) async {
    String? userId;

    // Autenticação se necessário
    if (authenticator != null) {
      final token = authenticator!.extractTokenFromRequest(
        request.uri,
        request.headers.value('Authorization') != null
            ? {'Authorization': request.headers.value('Authorization')!}
            : {},
      );

      if (config.requireAuth && token == null) {
        await connection.close(
          WsCloseCodes.authRequired,
          'Authentication required',
        );
        return;
      }

      if (token != null) {
        final authResult = await authenticator!.authenticate(connection, token);
        if (!authResult.success) {
          await connection.close(WsCloseCodes.authFailed, authResult.error);
          return;
        }
        userId = authResult.userId;
      }
    }

    // Cria sessão
    final session = _sessionManager.createSession(
      userId: userId,
      connection: connection,
    );

    // Inicia heartbeat
    _heartbeatManager.monitor(session);

    // Envia confirmação de conexão
    final connectMsg = WsMessage(
      version: config.protocolVersion,
      event: WsEvents.sessionCreated,
      payload: {'sessionId': session.sessionId, 'userId': userId},
    );
    connection.send(connectMsg);

    metrics?.onSessionCreated();

    // Escuta mensagens
    _subscriptions.add(
      connection.messages.listen(
        (message) => _handleMessage(session, connection, message),
        onError: (error) => _handleError(session, connection, error),
        onDone: () => _handleDisconnect(session, connection),
      ),
    );

    // Escuta erros de protocolo
    _subscriptions.add(
      connection.errors.listen(
        (error) => _handleError(session, connection, error),
      ),
    );
  }

  /// Trata mensagem recebida
  Future<void> _handleMessage(
    WsSession session,
    WsConnection connection,
    WsMessage message,
  ) async {
    // Atualiza atividade
    session.touch();

    metrics?.onMessageReceived(message.event);

    // Cria contexto
    final context = WsContext(
      session: session,
      connection: connection,
      message: message,
    );

    // Despacha
    final response = await _dispatcher.dispatch(context);

    // Envia resposta se houver
    if (response != null) {
      connection.send(response);
      metrics?.onMessageSent(response.event);
    }
  }

  /// Trata erro
  void _handleError(WsSession session, WsConnection connection, Object error) {
    print('Connection error for session ${session.sessionId}: $error');
    metrics?.onError(error);
  }

  /// Trata desconexão
  void _handleDisconnect(WsSession session, WsConnection connection) {
    // Suspende sessão (não fecha imediatamente para permitir reconexão)
    if (session.isActive) {
      _sessionManager.suspendSession(session.sessionId);
    }
  }

  /// Broadcast para todas as sessões ativas
  void broadcast(WsMessage message, {bool Function(WsSession)? filter}) {
    for (final session in _sessionManager.sessions) {
      if (!session.hasConnection) continue;
      if (filter != null && !filter(session)) continue;

      try {
        session.connection!.send(message);
        metrics?.onMessageSent(message.event);
      } catch (_) {
        // Ignora erros individuais
      }
    }
  }

  /// Broadcast para uma sala
  int broadcastToRoom(
    String roomId,
    WsMessage message, {
    String? excludeSessionId,
  }) {
    return _roomManager.broadcast(
      roomId,
      message,
      excludeSessionId: excludeSessionId,
    );
  }

  /// Configura pub/sub para escala
  Future<void> _setupPubSub() async {
    // Subscribe no canal de broadcast
    final broadcastStream = await pubSub!.subscribe('ws:broadcast');
    _subscriptions.add(
      broadcastStream.listen((message) {
        broadcast(message);
      }),
    );

    // Subscribe no canal de salas
    final roomStream = await pubSub!.subscribe('ws:room:*');
    _subscriptions.add(
      roomStream.listen((message) {
        final roomId = message.payload['_roomId'] as String?;
        if (roomId != null) {
          broadcastToRoom(roomId, message);
        }
      }),
    );
  }
}
