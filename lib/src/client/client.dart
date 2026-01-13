import 'dart:async';
import 'dart:io';

import '../protocol/events.dart';
import '../protocol/message.dart';
import '../utils/id_generator.dart';

/// Callback para mensagens
typedef WsClientHandler = void Function(Map<String, dynamic> data);

/// Cliente WebSocket com suporte ao protocolo WsCore.
///
/// Funcionalidades:
/// - Conexão e Reconexão automática
/// - Handshake de protocolo
/// - Resposta automática a Ping/Pong
/// - API fluente para envio e escuta de eventos
/// - Suporte a Request-Response (RPC)
class WsClient {
  final String url;
  final String protocolVersion;
  final Duration reconnectInterval;
  final Map<String, String>? headers;
  
  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  
  // Event handlers
  final Map<String, List<WsClientHandler>> _handlers = {};

  // Request-Response
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  final _uuid = const UuidGenerator();
  
  // Status streams
  final _statusController = StreamController<bool>.broadcast();
  
  /// Stream de status de conexão (true=conectado, false=desconectado)
  Stream<bool> get onConnectionChanged => _statusController.stream;
  
  /// Se está conectado
  bool get isConnected => _socket?.readyState == WebSocket.open;

  WsClient(this.url, {
    this.protocolVersion = '1.0',
    this.reconnectInterval = const Duration(seconds: 3),
    this.headers,
  });

  /// Conecta ao servidor
  Future<void> connect() async {
    if (_isDisposed) throw StateError('Client is disposed');
    if (isConnected) return;

    try {
      _socket = await WebSocket.connect(url, headers: headers);
      
      // Notifica conexão
      if (!_statusController.isClosed) {
        _statusController.add(true);
      }
      
      _socket!.listen(
        (data) => _handleData(data),
        onError: (e) {
            _handleDisconnect();
        },
        onDone: () {
            _handleDisconnect();
        },
      );
      
    } catch (e) {
      _handleDisconnect();
    }
  }
  
  void _handleDisconnect() {
    if (_isDisposed) return;
    
    if (isConnected) {
       if (!_statusController.isClosed) {
         _statusController.add(false);
       }
    }
    _socket = null;

    // Reject all pending requests
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(const SocketException('Disconnected'));
      }
    }
    _pendingRequests.clear();
    
    // Schedule reconnect
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectInterval, connect);
  }

  void _handleData(dynamic data) {
    if (data is String) {
      try {
        final message = WsMessage.fromJson(data);
        _handleMessage(message);
      } catch (e) {
        // Ignora mensagens mal formadas
      }
    }
  }

  void _handleMessage(WsMessage message) {
    // 1. Verifica se é resposta de um request
    if (message.correlationId != null) {
      final completer = _pendingRequests.remove(message.correlationId);
      if (completer != null) {
        if (message.event == 'sys.error') {
          completer.completeError(message.payload);
        } else {
          completer.complete(message.payload);
        }
        return; // Request handled, don't trigger generic listeners
      }
    }

    // System events
    if (message.event == WsEvents.ping) {
       send(WsEvents.pong, {'t': message.payload['t']});
       return;
    }
    
    // User events
    final handlers = _handlers[message.event];
    if (handlers != null) {
      for (final handler in handlers) {
        try {
          handler(message.payload);
        } catch (_) {
          // Ignora erros no handler do usuário
        }
      }
    }
  }

  /// Envia mensagem
  void send(String event, [Map<String, dynamic>? data]) {
    if (!isConnected) {
        return;
    }
    
    final message = WsMessage(
      version: protocolVersion,
      event: event,
      payload: data ?? {},
      timestamp: DateTime.now(),
    );
    
    _socket!.add(message.toJson());
  }

  /// Envia requisição e aguarda resposta
  Future<Map<String, dynamic>> request(String event, [Map<String, dynamic>? data]) {
    if (!isConnected) throw const SocketException('Client not connected');

    final correlationId = _uuid.generate();
    final completer = Completer<Map<String, dynamic>>();

    // Guarda o completer para resolver depois
    _pendingRequests[correlationId] = completer;

    // Envia com o correlationId
    final message = WsMessage(
      version: protocolVersion,
      event: event,
      payload: data ?? {},
      timestamp: DateTime.now(),
      correlationId: correlationId,
    );

    _socket!.add(message.toJson());

    // Timeout de segurança
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      _pendingRequests.remove(correlationId);
      throw TimeoutException('Request timed out');
    });
  }
  
  /// Registra listener
  void on(String event, WsClientHandler handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }
  
  /// Remove listener
  void off(String event) {
    _handlers.remove(event);
  }

  /// Fecha conexão
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _socket?.close();
    _statusController.close();
  }
}
