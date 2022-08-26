import 'package:remoter/remoter.dart';
import 'package:test/test.dart';
import 'utils/run_fake_async.dart';

void main() {
  group("simple apis", () {
    test("retry works on query error status", () async {
      final client = RemoterClient();
      bool passError = false;
      await client.fetch("cache", () async {
        if (passError == true) {
          return "test";
        }
        passError = true;
        throw Error();
      });
      expect(client.getData("cache")?.status, RemoterStatus.error);
      await client.retry("cache");
      expect(client.getData("cache")?.data, "test");
    });
    test("invalidate query works", () async {
      final client = RemoterClient();
      bool pass = false;
      await client.fetch("cache", () async {
        if (pass == true) {
          return "new";
        }
        pass = true;
        return "stale";
      });
      expect(client.getData("cache")?.data, "stale");
      await client.invalidateQuery("cache");
      expect(client.getData("cache")?.data, "new");
    });
    test("is stale works", () async {
      final client = RemoterClient(
        options: RemoterClientOptions(staleTime: 1000),
      );
      runFakeAsync((async) async {
        await client.fetch("cache", () async => "test");
        expect(client.isQueryStale("cache"), false);
        async.elapse(const Duration(milliseconds: 1000));
        expect(client.isQueryStale("cache"), true);
      });
    });
  });
  group("actions on listeners count", () {
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
      runFakeAsync((async) async {
        // increase listener counts
        final f = client.getStream("cache").listen((event) {});
        await client.fetch<String>("cache", () async => "str");
        expect(client.getData<String>("cache")?.data, "str");
        // decrease listener count to start timer
        f.cancel();
        async.elapse(const Duration(milliseconds: 5000));
        expect(client.getData<String>("cache"), isNull);
      });
    });
    test(
      "if new listener is created after timer started, cache shouldn't be cleared",
      () async {
        final client = RemoterClient(
          options: RemoterClientOptions(cacheTime: 5000),
        );
        runFakeAsync((async) async {
          // increase listener counts
          final f = client.getStream("cache").listen((event) {});
          await client.fetch<String>("cache", () async => "str");
          expect(client.getData<String>("cache")?.data, "str");
          // decrease listener count to start timer
          f.cancel();
          async.elapse(const Duration(milliseconds: 1000));
          // start new listener
          client.getStream("cache").listen((event) {});
          async.elapse(const Duration(milliseconds: 4000));
          expect(client.getData<String>("cache")?.data, "str");
        });
      },
    );
  });
}
