import '../protocol/events.dart';
import '../protocol/message.dart';
import 'handler.dart';
import '../exceptions/exceptions.dart';

/// Registro de handler com metadados
class HandlerRegistration {
  /// Handler a ser executado
  final WsHandler handler;

  /// Versões suportadas (vazio = todas)
  final Set<String> versions;

  /// Se requer autenticação
  final bool requiresAuth;

  /// Schema de validação (campo -> validador)
  final Map<String, bool Function(dynamic)>? schema;

  const HandlerRegistration({
    required this.handler,
    this.versions = const {},
    this.requiresAuth = false,
    this.schema,
  });
}

/// Dispatcher de eventos WebSocket.
///
/// Responsabilidades:
/// - Mapear evento → handler
/// - Suporte a versionamento
/// - Pipeline de middlewares
/// - Fallback para versões antigas
class WsDispatcher {
  /// Mapa de handlers por evento
  final Map<String, List<HandlerRegistration>> _handlers = {};

  /// Middlewares globais
  final List<WsMiddleware> _middlewares = [];

  /// Handler padrão para eventos não encontrados
  WsHandler? _notFoundHandler;

  /// Handler de erro
  Future<WsMessage?> Function(
    WsContext context,
    Object error,
    StackTrace stack,
  )?
  _errorHandler;

  /// Versão padrão do protocolo
  final String defaultVersion;

  WsDispatcher({this.defaultVersion = '1.0'});

  /// Registra um handler para um evento
  void on(
    String event,
    WsHandler handler, {
    Set<String>? versions,
    bool requiresAuth = false,
    Map<String, bool Function(dynamic)>? schema,
  }) {
    final registration = HandlerRegistration(
      handler: handler,
      versions: versions ?? {},
      requiresAuth: requiresAuth,
      schema: schema,
    );

    _handlers.putIfAbsent(event, () => []).add(registration);
  }

  /// Registra handler com versão específica
  void onVersion(
    String event,
    String version,
    WsHandler handler, {
    bool requiresAuth = false,
    Map<String, bool Function(dynamic)>? schema,
  }) {
    on(
      event,
      handler,
      versions: {version},
      requiresAuth: requiresAuth,
      schema: schema,
    );
  }

  /// Registra middleware global
  void use(WsMiddleware middleware) {
    _middlewares.add(middleware);
  }

  /// Define handler para evento não encontrado
  void onNotFound(WsHandler handler) {
    _notFoundHandler = handler;
  }

  /// Define handler de erro
  void onError(
    Future<WsMessage?> Function(
      WsContext context,
      Object error,
      StackTrace stack,
    )
    handler,
  ) {
    _errorHandler = handler;
  }

  /// Remove handler de um evento
  void off(String event) {
    _handlers.remove(event);
  }

  /// Verifica se um evento tem handler
  bool hasHandler(String event) {
    return _handlers.containsKey(event);
  }

  /// Despacha uma mensagem para o handler apropriado
  Future<WsMessage?> dispatch(WsContext context) async {
    try {
      // 1. Executa middlewares
      for (final middleware in _middlewares) {
        final shouldContinue = await middleware(context);
        if (!shouldContinue) {
          return null; // Middleware bloqueou
        }
      }

      // 2. Busca handler para o evento
      final event = context.event;
      final version = context.message.version;

      final registration = _findHandler(event, version);

      if (registration == null) {
        // Handler não encontrado
        if (_notFoundHandler != null) {
          return await _notFoundHandler!(context);
        }

        return _createErrorMessage(
          context,
          WsErrorCodes.handlerNotFound,
          'Handler not found for event: $event',
        );
      }

      // 3. Verifica autenticação se necessário
      if (registration.requiresAuth && context.userId == null) {
        return _createErrorMessage(
          context,
          WsErrorCodes.authRequired,
          'Authentication required',
        );
      }

      // 4. Valida schema se houver
      if (registration.schema != null) {
        for (final entry in registration.schema!.entries) {
          final key = entry.key;
          final validator = entry.value;
          final value = context.payload[key];
          if (!validator(value)) {
            return _createErrorMessage(
              context,
              WsErrorCodes.validationFailed,
              'Validation failed for field: $key',
            );
          }
        }
      }

      // 5. Executa handler
      final result = await registration.handler(context);

      if (result is WsMessage) {
        return result;
      }
      
      if (result is Map<String, dynamic>) {
        return WsMessage(
          version: context.message.version,
          event: '${context.event}.response',
          payload: result,
          correlationId: context.correlationId,
        );
      }

      return null;
    } catch (error, stack) {
      // Verifica se é erro de validação (WsContext.bind)
      if (error is WsValidationException) {
        return _createErrorMessage(
          context,
          WsErrorCodes.validationFailed,
          error.message,
        );
      }

      // Handler de erro
      if (_errorHandler != null) {
        return await _errorHandler!(context, error, stack);
      }

      return _createErrorMessage(
        context,
        WsErrorCodes.internalError,
        'Internal server error: $error',
      );
    }
  }

  /// Busca handler compatível com a versão
  HandlerRegistration? _findHandler(String event, String version) {
    final handlers = _handlers[event];
    if (handlers == null || handlers.isEmpty) return null;

    // Procura handler que suporta a versão
    for (final registration in handlers) {
      if (registration.versions.isEmpty ||
          registration.versions.contains(version)) {
        return registration;
      }
    }

    // Fallback: retorna primeiro handler se nenhum for específico para versão
    return handlers.first;
  }

  /// Cria mensagem de erro
  WsMessage _createErrorMessage(WsContext context, int code, String message) {
    return WsMessage(
      version: context.message.version,
      event: WsEvents.error,
      payload: {'code': code, 'message': message},
      correlationId: context.correlationId,
    );
  }
}
