import 'dart:async';
import 'dart:math';

/// Returns delay for current attempt with exponential backoff in milliseconds
int delayAttempt(int attempt, int maxDelay) {
  if (attempt == 0) {
    return 0;
  }
  final delay = 100 * pow(2, min(attempt, 31));
  return min(delay.toInt(), maxDelay);
}

/// [fn] will be called until [maxAttempts] reached or future resolves
Future<T> retryFuture<T>(
  FutureOr<T> Function() fn, {

  /// Maximum delay retries should have in milliseconds
  required int maxDelay,

  /// Defines maximum number of attempts can be made
  required int maxAttempts,

  /// Every time [fn] fails [onFail] function will be called with current number of attempts
  /// If returns true retry will be cancelled and error will be thrown
  FutureOr<bool> Function(int)? onFail,
}) async {
  int attempt = 0;
  while (true) {
    attempt++;
    try {
      return await fn();
    } catch (_) {
      final cancel = await onFail?.call(attempt);
      if (attempt >= maxAttempts || cancel == true) {
        rethrow;
      }
    }

    final currentDelay = Duration(
      milliseconds: delayAttempt(attempt, maxDelay),
    );
    // Delay between retries
    await Future.delayed(currentDelay);
  }
}
