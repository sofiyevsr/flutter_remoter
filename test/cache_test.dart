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
  });

  group("stream tests", () {
    test("entry removed after cache expires", () {
      final cache = RemoterCache();

      fakeAsync((async) {
        cache.setEntry<String>(
          "cache",
          "str",
          CacheOptions(cacheTime: 5000),
        );
        async.elapse(const Duration(milliseconds: 5000));
        expect(cache.getData("cache"), null);
      });
    });

    test("stream receives latest value", () {
      final cache = RemoterCache();
      cache.getStream<String>("cache").listen(
        expectAsync1<void, CacheEvent<String>>(
          (value) {
            expect(value.data, "str");
          },
        ),
      );
      cache.setEntry<String>("cache", "str");
    });

  });
}
