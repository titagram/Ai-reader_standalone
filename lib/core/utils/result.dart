/// A generic result wrapper for operations that can succeed or fail
sealed class Result<T> {
  const Result();

  /// Creates a success result
  factory Result.success(T data) = Success<T>;

  /// Creates a failure result
  factory Result.failure(String message, [Object? error]) = Failure<T>;

  /// Returns true if this is a success result
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result
  bool get isFailure => this is Failure<T>;

  /// Gets the data if success, null otherwise
  T? get dataOrNull => switch (this) {
        Success<T>(data: final data) => data,
        Failure<T>() => null,
      };

  /// Gets the error message if failure, null otherwise
  String? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(message: final msg) => msg,
      };

  /// Maps the success value
  Result<R> map<R>(R Function(T data) mapper) => switch (this) {
        Success<T>(data: final data) => Result.success(mapper(data)),
        Failure<T>(message: final msg, error: final err) =>
          Result.failure(msg, err),
      };

  /// Transforms this result using the given functions
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String message, Object? error) onFailure,
  }) =>
      switch (this) {
        Success<T>(data: final data) => onSuccess(data),
        Failure<T>(message: final msg, error: final err) => onFailure(msg, err),
      };
}

/// Represents a successful result
final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

/// Represents a failed result
final class Failure<T> extends Result<T> {
  const Failure(this.message, [this.error]);

  final String message;
  final Object? error;
}
