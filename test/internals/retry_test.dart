import 'package:flutter_remoter/internals/retry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/run_fake_async.dart';

void main() {
  test("Function should be run given times before throwing", () {
    int count = 0;
    Future<void> getData() async {
      count++;
      throw Error();
    }

    runFakeAsync((time) async {
      expect(
        retryFuture(() => getData(), maxDelay: 1000, maxRetries: 3),
        throwsA(isA<Error>()),
      );
      time.elapse(
        const Duration(seconds: 3),
      );
      expect(count, 3);
    });
  });

  test("If onFail method returns true function should throw immediately", () {
    int count = 0;
    Future<void> getData() async {
      count++;
      throw Error();
    }

    runFakeAsync((time) async {
      expect(
        retryFuture(
          () => getData(),
          onFail: (_) => true,
          maxDelay: 1000,
          maxRetries: 3,
        ),
        throwsA(isA<Error>()),
      );
      expect(count, 1);
    });
  });
}
