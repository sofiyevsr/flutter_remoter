import 'package:fake_async/fake_async.dart';
import 'package:remoter/remoter.dart';
import 'package:test/test.dart';

void main() {
  group("simple apis work", () {
    test("is stale works", () async {
      final client = RemoterClient(
        options: RemoterClientOptions(staleTime: 1000),
      );
      _runFakeAsync((async) async {
        await client.fetch("cache", () async => "test");
        expect(client.isQueryStale("cache"), false);
        async.elapse(const Duration(milliseconds: 10000));
        expect(client.isQueryStale("cache"), true);
      });
    });
  });
  group("actions on listeners count works", () {
    test("count is updated", () {
      final client = RemoterClient();
      expect(client.listeners["cache"], isNull);
      final f = client.getStream("cache").listen((event) {});
      expect(client.listeners["cache"], 1);
      final s = client.getStream("cache").listen((event) {});
      expect(client.listeners["cache"], 2);
      f.cancel();
      expect(client.listeners["cache"], 1);
      s.cancel();
      expect(client.listeners["cache"], isNull);
    });
    test("if no listener is there cache should be removed for key", () async {
      final client = RemoterClient(
        options: RemoterClientOptions(cacheTime: 5000),
      );
      _runFakeAsync((async) async {
        // increase listener counts
        final f = client.getStream("cache").listen((event) {});
        await client.fetch<String>("cache", () async => "str");
        expect(client.getData<String>("cache")?.data, "str");
        // decrease listener count to start timer
        f.cancel();
        async.elapse(const Duration(milliseconds: 6000));
        expect(client.getData<String>("cache"), isNull);
      });
    });
    test(
      "if new listener is created after timer started, cache shouldn't be cleared",
      () async {
        final client = RemoterClient(
          options: RemoterClientOptions(cacheTime: 5000),
        );
        _runFakeAsync((async) async {
          // increase listener counts
          final f = client.getStream("cache").listen((event) {});
          await client.fetch<String>("cache", () async => "str");
          expect(client.getData<String>("cache")?.data, "str");
          // decrease listener count to start timer
          f.cancel();
          async.elapse(const Duration(milliseconds: 1000));
          // start new listener
          client.getStream("cache").listen((event) {});
          async.elapse(const Duration(milliseconds: 5000));
          expect(client.getData<String>("cache")?.data, "str");
        });
      },
    );
  });
}

Future<T> _runFakeAsync<T>(Future<T> Function(FakeAsync time) f) async {
  return FakeAsync().run((FakeAsync time) async {
    bool pump = true;
    final Future<T> future = f(time).whenComplete(() => pump = false);
    while (pump) {
      time.flushMicrotasks();
    }
    return future;
  });
}
