/// Generic result type representing either a success [Ok] or a failure [Err].
sealed class Result<T, E> {
  const Result();

  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;

  R when<R>({required R Function(T value) ok, required R Function(E error) err}) {
    final self = this;
    if (self is Ok<T, E>) return ok(self.value);
    if (self is Err<T, E>) return err(self.error);
    throw StateError('Unknown Result subtype: $self');
  }
}

class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);

  final T value;
}

class Err<T, E> extends Result<T, E> {
  const Err(this.error);

  final E error;
}
