import 'dart:async';

import '../dispatcher/handler.dart';
import '../exceptions/exceptions.dart';
import '../protocol/events.dart';
import '../protocol/message.dart';

/// Configuração do rate limiter
class RateLimitConfig {
  /// Máximo de requests permitidos na janela
  final int maxRequests;

  /// Tamanho da janela de tempo
  final Duration window;

  /// Se deve aplicar por sessão (true) ou por evento (false)
  final bool perSession;

  /// Eventos isentos de rate limit
  final Set<String> exemptEvents;

  const RateLimitConfig({
    this.maxRequests = 100,
    this.window = const Duration(seconds: 60),
    this.perSession = true,
    this.exemptEvents = const {'sys.ping', 'sys.pong', 'sys.reconnect.request'},
  });
}

/// Estado do rate limit para uma chave
class _RateLimitState {
  final List<DateTime> requests = [];
  DateTime? blockedUntil;
}

/// Rate Limiter para proteção contra abuse.
///
/// Limita o número de requests por sessão/evento em uma janela de tempo.
class RateLimiter {
  /// Configuração
  final RateLimitConfig config;

  /// Estados por chave (sessionId ou sessionId:event)
  final Map<String, _RateLimitState> _states = {};

  /// Timer para cleanup
  Timer? _cleanupTimer;

  RateLimiter({RateLimitConfig? config})
    : config = config ?? const RateLimitConfig() {
    // Cleanup periódico de estados antigos
    _cleanupTimer = Timer.periodic(
      config?.window ?? const Duration(seconds: 60),
      (_) => _cleanup(),
    );
  }

  /// Verifica se request é permitido
  ///
  /// Retorna `true` se permitido, `false` se bloqueado.
  /// Lança [WsRateLimitException] se bloqueado.
  bool checkLimit(String sessionId, String event) {
    // Eventos isentos
    if (config.exemptEvents.contains(event)) {
      return true;
    }

    final key = config.perSession ? sessionId : '$sessionId:$event';
    final now = DateTime.now();

    // Busca ou cria estado
    final state = _states.putIfAbsent(key, () => _RateLimitState());

    // Verifica se está bloqueado
    if (state.blockedUntil != null && now.isBefore(state.blockedUntil!)) {
      final retryAfter = state.blockedUntil!.difference(now);
      throw WsRateLimitException(retryAfter: retryAfter);
    }

    // Remove requests fora da janela
    final windowStart = now.subtract(config.window);
    state.requests.removeWhere((t) => t.isBefore(windowStart));

    // Verifica limite
    if (state.requests.length >= config.maxRequests) {
      // Bloqueia até o final da janela
      state.blockedUntil = now.add(config.window);
      final retryAfter = config.window;
      throw WsRateLimitException(retryAfter: retryAfter);
    }

    // Registra request
    state.requests.add(now);
    return true;
  }

  /// Reseta limite para uma sessão
  void reset(String sessionId) {
    _states.removeWhere((key, _) => key.startsWith(sessionId));
  }

  /// Limpa estados expirados
  void _cleanup() {
    final now = DateTime.now();
    final windowStart = now.subtract(config.window);

    final keysToRemove = <String>[];

    for (final entry in _states.entries) {
      final state = entry.value;

      // Remove requests antigos
      state.requests.removeWhere((t) => t.isBefore(windowStart));

      // Remove bloqueio expirado
      if (state.blockedUntil != null && now.isAfter(state.blockedUntil!)) {
        state.blockedUntil = null;
      }

      // Marca para remoção se vazio
      if (state.requests.isEmpty && state.blockedUntil == null) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _states.remove(key);
    }
  }

  /// Limpa recursos
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _states.clear();
  }
}

/// Cria middleware de rate limiting.
///
/// Exemplo:
/// ```dart
/// server.use(rateLimitMiddleware(
///   maxRequests: 100,
///   window: Duration(seconds: 60),
/// ));
/// ```
WsMiddleware rateLimitMiddleware({
  int maxRequests = 100,
  Duration window = const Duration(seconds: 60),
  bool perSession = true,
  Set<String>? exemptEvents,
}) {
  final limiter = RateLimiter(
    config: RateLimitConfig(
      maxRequests: maxRequests,
      window: window,
      perSession: perSession,
      exemptEvents:
          exemptEvents ??
          const {'sys.ping', 'sys.pong', 'sys.reconnect.request'},
    ),
  );

  return (WsContext context) async {
    try {
      limiter.checkLimit(context.sessionId, context.event);
      return true;
    } on WsRateLimitException catch (e) {
      // Envia erro de rate limit
      context.session.connection?.send(
        WsMessage(
          version: context.message.version,
          event: WsEvents.error,
          payload: {
            'code': WsErrorCodes.rateLimitExceeded,
            'message': e.message,
            'retryAfterMs': e.retryAfter.inMilliseconds,
          },
          correlationId: context.correlationId,
        ),
      );
      return false; // Bloqueia request
    }
  };
}

/// Cria middleware de rate limiting com configuração customizada
WsMiddleware rateLimitMiddlewareWithConfig(RateLimitConfig config) {
  final limiter = RateLimiter(config: config);

  return (WsContext context) async {
    try {
      limiter.checkLimit(context.sessionId, context.event);
      return true;
    } on WsRateLimitException catch (e) {
      context.error(
        code: WsErrorCodes.rateLimitExceeded,
        message: e.message,
        details: {'retryAfterMs': e.retryAfter.inMilliseconds},
      );
      return false;
    }
  };
}
