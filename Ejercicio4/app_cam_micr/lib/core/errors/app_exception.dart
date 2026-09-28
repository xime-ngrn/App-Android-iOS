/// Error de negocio con un mensaje listo para mostrarse al usuario.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}
