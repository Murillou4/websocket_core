import 'server.dart';

/// Controlador base para organizar rotas e lógica
abstract class WsController {
  /// Registra handlers no servidor
  void register(WsServer server);
}
