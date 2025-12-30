import 'dart:async';

import '../protocol/events.dart';
import '../protocol/message.dart';
import '../session/session.dart';

/// Callback quando heartbeat falha
typedef HeartbeatTimeoutCallback = void Function(WsSession session);

/// Gerenciador de heartbeat (ping/pong).
///
/// Responsabilidades:
/// - Enviar ping periódico
/// - Detectar timeout (falta de pong)
/// - Marcar sessão como suspensa
class HeartbeatManager {
  /// Intervalo entre pings
  final Duration interval;

  /// Tempo máximo para receber pong
  final Duration timeout;

  /// Versão do protocolo para mensagens
  final String protocolVersion;

  /// Sessões sendo monitoradas
  final Map<String, _HeartbeatState> _states = {};

  /// Timer principal
  Timer? _timer;

  /// Callback de timeout
  HeartbeatTimeoutCallback? onTimeout;

  HeartbeatManager({
    this.interval = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 10),
    this.protocolVersion = '1.0',
    this.onTimeout,
  });

  /// Inicia monitoramento para uma sessão
  void monitor(WsSession session) {
    if (session.isClosed) return;

    final state = _HeartbeatState(
      sessionId: session.sessionId,
      session: session,
    );

    _states[session.sessionId] = state;

    // Inicia timer global se não estiver rodando
    _ensureTimerRunning();
  }

  /// Para monitoramento de uma sessão
  void stopMonitoring(String sessionId) {
    final state = _states.remove(sessionId);
    state?.pendingTimer?.cancel();
  }

  /// Processa pong recebido
  void handlePong(String sessionId) {
    final state = _states[sessionId];
    if (state == null) return;

    state.pendingTimer?.cancel();
    state.pendingTimer = null;
    state.lastPongAt = DateTime.now();
    state.missedPongs = 0;
  }

  /// Inicia o timer global
  void start() {
    _ensureTimerRunning();
  }

  /// Para o timer global
  void stop() {
    _timer?.cancel();
    _timer = null;

    // Cancela todos os timers pendentes
    for (final state in _states.values) {
      state.pendingTimer?.cancel();
    }
    _states.clear();
  }

  /// Garante que o timer está rodando
  void _ensureTimerRunning() {
    _timer ??= Timer.periodic(interval, (_) => _sendPings());
  }

  /// Envia ping para todas as sessões monitoradas
  void _sendPings() {
    final now = DateTime.now();

    for (final state in _states.values) {
      final session = state.session;

      // Ignora sessões sem conexão ou fechadas
      if (!session.hasConnection || session.isClosed) continue;

      final connection = session.connection!;

      // Cria mensagem de ping
      final pingMessage = WsMessage(
        version: protocolVersion,
        event: WsEvents.ping,
        payload: {'t': now.millisecondsSinceEpoch},
      );

      try {
        connection.send(pingMessage);
        state.lastPingAt = now;

        // Inicia timer de timeout para este ping
        state.pendingTimer?.cancel();
        state.pendingTimer = Timer(timeout, () {
          _handleTimeout(state);
        });
      } catch (e) {
        // Falha ao enviar - provavelmente conexão caiu
        _handleTimeout(state);
      }
    }
  }

  /// Processa timeout de pong
  void _handleTimeout(_HeartbeatState state) {
    state.missedPongs++;
    state.pendingTimer = null;

    final session = state.session;

    // Notifica callback
    onTimeout?.call(session);
  }

  /// Limpa recursos
  void dispose() {
    stop();
  }
}

/// Estado interno do heartbeat por sessão
class _HeartbeatState {
  final String sessionId;
  final WsSession session;
  DateTime? lastPingAt;
  DateTime? lastPongAt;
  Timer? pendingTimer;
  int missedPongs = 0;

  _HeartbeatState({required this.sessionId, required this.session});
}
