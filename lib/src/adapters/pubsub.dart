import 'dart:async';

import '../protocol/message.dart';

/// Interface para Pub/Sub externo.
///
/// O package NÃO implementa Pub/Sub.
/// Você deve implementar esta interface conforme sua stack:
/// - Redis Pub/Sub
/// - NATS
/// - RabbitMQ
/// - Etc.
///
/// Esta interface permite escalar para múltiplos servidores.
abstract class WsPubSub {
  const WsPubSub();

  /// Publica uma mensagem em um canal
  Future<void> publish(String channel, WsMessage message);

  /// Subscribe em um canal
  ///
  /// Suporta wildcards com '*'. Ex: 'ws:room:*'
  Future<Stream<WsMessage>> subscribe(String channel);

  /// Unsubscribe de um canal
  Future<void> unsubscribe(String channel);

  /// Fecha a conexão
  Future<void> close();
}

/// Event Bus local (em memória) - NÃO ESCALA.
///
/// Útil para desenvolvimento e testes.
/// Em produção, use um adapter real (Redis, NATS, etc).
class LocalEventBus implements WsPubSub {
  final Map<String, StreamController<WsMessage>> _channels = {};
  final Map<String, Set<StreamController<WsMessage>>> _wildcardSubscribers = {};

  @override
  Future<void> publish(String channel, WsMessage message) async {
    // Publica no canal específico
    if (_channels.containsKey(channel)) {
      _channels[channel]!.add(message);
    }

    // Publica para subscribers de wildcards
    for (final entry in _wildcardSubscribers.entries) {
      final pattern = entry.key;
      if (_matchesWildcard(channel, pattern)) {
        for (final controller in entry.value) {
          controller.add(message);
        }
      }
    }
  }

  @override
  Future<Stream<WsMessage>> subscribe(String channel) async {
    // Wildcard subscription
    if (channel.contains('*')) {
      final controller = StreamController<WsMessage>.broadcast();
      _wildcardSubscribers.putIfAbsent(channel, () => {}).add(controller);
      return controller.stream;
    }

    // Canal específico
    _channels.putIfAbsent(
      channel,
      () => StreamController<WsMessage>.broadcast(),
    );
    return _channels[channel]!.stream;
  }

  @override
  Future<void> unsubscribe(String channel) async {
    if (channel.contains('*')) {
      final controllers = _wildcardSubscribers.remove(channel);
      if (controllers != null) {
        for (final controller in controllers) {
          await controller.close();
        }
      }
    } else {
      final controller = _channels.remove(channel);
      await controller?.close();
    }
  }

  @override
  Future<void> close() async {
    for (final controller in _channels.values) {
      await controller.close();
    }
    _channels.clear();

    for (final controllers in _wildcardSubscribers.values) {
      for (final controller in controllers) {
        await controller.close();
      }
    }
    _wildcardSubscribers.clear();
  }

  /// Verifica se um canal corresponde a um pattern wildcard
  bool _matchesWildcard(String channel, String pattern) {
    // Simples: 'ws:room:*' corresponde a 'ws:room:123'
    final regexPattern = pattern.replaceAll('.', r'\.').replaceAll('*', '.*');

    return RegExp('^$regexPattern\$').hasMatch(channel);
  }
}
