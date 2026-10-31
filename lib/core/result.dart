sealed class Result<T, E> {
  const Result();
}

final class Success<T, E> extends Result<T, E> {
  const Success(this.value);

  final T value;
}

final class Err<T, E> extends Result<T, E> {
  const Err(this.error);

  final E error;
}
