import 'dart:async';
import 'dart:io';

import '../protocol/protocol.dart';
import '../utils/id_generator.dart';
import 'connection.dart';

/// Callback para eventos de conexão
typedef ConnectionCallback = void Function(WsConnection connection);

/// Gerenciador de conexões WebSocket.
///
/// Responsabilidades:
/// - Registrar conexões ativas
/// - Gerar IDs únicos de conexão
/// - Buscar conexões por ID
/// - Emitir eventos de lifecycle
class WsConnectionManager {
  /// Protocolo para as conexões
  final WsProtocol _protocol;

  /// Gerador de IDs
  final IdGenerator _idGenerator;

  /// Mapa de conexões ativas
  final Map<String, WsConnection> _connections = {};

  /// Callbacks de nova conexão
  final List<ConnectionCallback> _onConnectCallbacks = [];

  /// Callbacks de desconexão
  final List<ConnectionCallback> _onDisconnectCallbacks = [];

  WsConnectionManager({WsProtocol? protocol, IdGenerator? idGenerator})
    : _protocol = protocol ?? const WsProtocol(),
      _idGenerator = idGenerator ?? const UuidGenerator();

  /// Número de conexões ativas
  int get connectionCount => _connections.length;

  /// Lista de IDs de conexões ativas
  Iterable<String> get connectionIds => _connections.keys;

  /// Lista de conexões ativas
  Iterable<WsConnection> get connections => _connections.values;

  /// Cria e registra uma nova conexão
  WsConnection createConnection(WebSocket socket) {
    final connectionId = _idGenerator.generate();

    final connection = WsConnection(
      connectionId: connectionId,
      socket: socket,
      protocol: _protocol,
    );

    _connections[connectionId] = connection;

    // Configura cleanup automático quando a conexão fechar
    connection.done.then((_) {
      _removeConnection(connectionId);
    });

    // Notifica callbacks
    for (final callback in _onConnectCallbacks) {
      callback(connection);
    }

    return connection;
  }

  /// Busca conexão por ID
  WsConnection? getConnection(String connectionId) {
    return _connections[connectionId];
  }

  /// Verifica se uma conexão existe
  bool hasConnection(String connectionId) {
    return _connections.containsKey(connectionId);
  }

  /// Fecha uma conexão específica
  Future<void> closeConnection(
    String connectionId, [
    int? code,
    String? reason,
  ]) async {
    final connection = _connections[connectionId];
    if (connection != null) {
      await connection.close(code, reason);
    }
  }

  /// Fecha todas as conexões
  Future<void> closeAll([int? code, String? reason]) async {
    final futures = _connections.values.map((c) => c.close(code, reason));
    await Future.wait(futures);
    _connections.clear();
  }

  /// Registra callback para nova conexão
  void onConnect(ConnectionCallback callback) {
    _onConnectCallbacks.add(callback);
  }

  /// Registra callback para desconexão
  void onDisconnect(ConnectionCallback callback) {
    _onDisconnectCallbacks.add(callback);
  }

  /// Remove callback de conexão
  void removeOnConnect(ConnectionCallback callback) {
    _onConnectCallbacks.remove(callback);
  }

  /// Remove callback de desconexão
  void removeOnDisconnect(ConnectionCallback callback) {
    _onDisconnectCallbacks.remove(callback);
  }

  /// Remove conexão do registro
  void _removeConnection(String connectionId) {
    final connection = _connections.remove(connectionId);
    if (connection != null) {
      for (final callback in _onDisconnectCallbacks) {
        callback(connection);
      }
    }
  }

  /// Broadcast para todas as conexões
  void broadcast(dynamic message, {bool Function(WsConnection)? filter}) {
    for (final connection in _connections.values) {
      if (filter != null && !filter(connection)) continue;
      if (!connection.isActive) continue;

      try {
        connection.sendRaw(message.toString());
      } catch (_) {
        // Ignora erros de envio individual
      }
    }
  }
}
