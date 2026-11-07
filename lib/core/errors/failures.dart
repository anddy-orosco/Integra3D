abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Error en el servidor de cálculo simbólico.']);
}

class CalculationFailure extends Failure {
  const CalculationFailure([super.message = 'La integral no converge o no admite antiderivada elemental.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No se pudo conectar con el motor matemático. Asegúrate de que el backend esté activo.']);
}
