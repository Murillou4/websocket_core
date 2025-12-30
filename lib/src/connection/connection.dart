import 'dart:async';
import 'dart:io';

import '../protocol/message.dart';
import '../protocol/protocol.dart';

/// Estado da conexão WebSocket
enum WsConnectionState {
  /// Conexão ativa e funcional
  active,

  /// Conexão fechada
  closed,
}

/// Wrapper da conexão WebSocket.
///
/// Responsabilidades:
/// - Gerar `connectionId` único
/// - Enviar/receber mensagens
/// - Gerenciar estado da conexão
/// - Emitir eventos de lifecycle
class WsConnection {
  /// ID único desta conexão
  final String connectionId;

  /// Socket WebSocket real
  final WebSocket _socket;

  /// Protocolo para serialização
  final WsProtocol _protocol;

  /// Estado atual da conexão
  WsConnectionState _state = WsConnectionState.active;

  /// ID da sessão associada (após handshake)
  String? _sessionId;

  /// Metadados da conexão
  final Map<String, dynamic> metadata = {};

  /// Timestamp da conexão
  final DateTime connectedAt = DateTime.now();

  /// Controller para mensagens recebidas
  final StreamController<WsMessage> _messageController =
      StreamController<WsMessage>.broadcast();

  /// Controller para erros
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();

  /// Controller para fechamento
  final Completer<int?> _closeCompleter = Completer<int?>();

  /// Subscription do socket
  StreamSubscription<dynamic>? _socketSubscription;

  WsConnection({
    required this.connectionId,
    required WebSocket socket,
    required WsProtocol protocol,
  }) : _socket = socket,
       _protocol = protocol {
    _setupListeners();
  }

  /// Estado atual
  WsConnectionState get state => _state;

  /// Se a conexão está ativa
  bool get isActive => _state == WsConnectionState.active;

  /// ID da sessão associada
  String? get sessionId => _sessionId;

  /// Stream de mensagens recebidas
  Stream<WsMessage> get messages => _messageController.stream;

  /// Stream de erros
  Stream<Object> get errors => _errorController.stream;

  /// Future que completa quando a conexão fecha
  Future<int?> get done => _closeCompleter.future;

  /// Associa uma sessão a esta conexão
  void attachSession(String sessionId) {
    _sessionId = sessionId;
  }

  /// Remove a sessão desta conexão
  void detachSession() {
    _sessionId = null;
  }

  /// Envia uma mensagem
  void send(WsMessage message) {
    if (!isActive) {
      throw StateError('Cannot send message on closed connection');
    }
    final serialized = _protocol.serialize(message);
    _socket.add(serialized);
  }

  /// Envia mensagem raw (string)
  void sendRaw(String data) {
    if (!isActive) {
      throw StateError('Cannot send on closed connection');
    }
    _socket.add(data);
  }

  /// Fecha a conexão
  Future<void> close([int? code, String? reason]) async {
    if (_state == WsConnectionState.closed) return;

    _state = WsConnectionState.closed;
    await _socketSubscription?.cancel();
    await _socket.close(code, reason);

    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete(code);
    }

    await _messageController.close();
    await _errorController.close();
  }

  /// Configura listeners do socket
  void _setupListeners() {
    _socketSubscription = _socket.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  /// Handler para dados recebidos
  void _onData(dynamic data) {
    if (data is! String) {
      _errorController.add(
        FormatException('Expected string, got ${data.runtimeType}'),
      );
      return;
    }

    final result = _protocol.validate(data);
    if (!result.isValid) {
      _errorController.add(FormatException(result.error ?? 'Invalid message'));
      return;
    }

    _messageController.add(result.message!);
  }

  /// Handler para erros
  void _onError(Object error) {
    _errorController.add(error);
  }

  /// Handler para fechamento
  void _onDone() {
    if (_state != WsConnectionState.closed) {
      _state = WsConnectionState.closed;
      if (!_closeCompleter.isCompleted) {
        _closeCompleter.complete(_socket.closeCode);
      }
      _messageController.close();
      _errorController.close();
    }
  }

  @override
  String toString() => 'WsConnection($connectionId)';
}
