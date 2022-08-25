import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

import 'package:remoter/src/cache.dart';

void main() {
  group("simple apis work", () {
    test('set data works', () {
      final cache = RemoterCache();
      cache.setEntry<String>("cache", "str");
      final d = cache.getData<String>("cache");
      expect(d, equals("str"));
    });
    test('delete data works', () {
      final cache = RemoterCache();
      cache.setEntry<String>("cache", "str");
      cache.deleteEntry("cache");
      final d = cache.getData<String>("cache");
      expect(d, isNull);
    });
  });

  group("stream tests", () {
    test("entry removed after cache expires", () {
      final cache = RemoterCache();

      fakeAsync((async) {
        cache.setEntry<String>(
          "cache",
          "str",
        );
        cache.startTimer("cache", 5000);
        async.elapse(const Duration(milliseconds: 5000));
        expect(cache.getData("cache"), isNull);
      });
    });

    test("entry not removed after timer stopped", () {
      final cache = RemoterCache();

      fakeAsync((async) {
        cache.setEntry<String>(
          "cache",
          "str",
        );
        cache.startTimer("cache", 5000);
        async.elapse(const Duration(milliseconds: 1000));
        cache.deleteTimer("cache");
        async.elapse(const Duration(milliseconds: 4000));
        expect(cache.getData("cache"), isNotNull);
      });
    });
  });
}
