import 'package:flutter_remoter/src/internals/client.dart';
import 'package:flutter_remoter/src/internals/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/run_fake_async.dart';

void main() {
  group("simple apis", () {
    test("set query data", () async {
      final client = RemoterClient();
      final stream = client.getStream<RemoterData<String>, String>("cache");
      client.setData(
        "cache",
        RemoterData<String>(
          key: "cache",
          data: "result",
          status: RemoterStatus.success,
        ),
      );
      stream.listen(expectAsync1((value) => expect(value.data, "result")));
    });

    test("retry works on query error status", () async {
      final client = RemoterClient(
        options: RemoterOptions(maxRetries: 0),
      );
      bool passError = false;
      await client.fetch<RemoterData<String>, String>("cache", execute: (_) {
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
      await client.fetch<RemoterData<String>, String>("cache", execute: (_) {
        if (pass == true) {
          return "new";
        }
        pass = true;
        return "stale";
      });
      // Required to be able to invalidate
      client.getStream("cache").listen((event) {});
      expect(client.getData("cache")?.data, "stale");
      await client.invalidateQuery("cache");
      expect(client.getData("cache")?.data, "new");
    });

    test("is stale works", () async {
      final client = RemoterClient();
      runFakeAsync((async) async {
        await client.fetch<RemoterData<String>, String>("cache", execute: (_) => "test");
        expect(client.isQueryStale("cache", 1000), false);
        async.elapse(const Duration(milliseconds: 1000));
        expect(client.isQueryStale("cache", 1000), true);
      });
    });
  });

  group("actions on listeners count", () {
    test("count is updated", () {
      final client = RemoterClient();
      expect(client.getListenersCount("cache"), isNull);
      final f = client.getStream("cache").listen((event) {});
      expect(client.getListenersCount("cache"), 1);
      final s = client.getStream("cache").listen((event) {});
      expect(client.getListenersCount("cache"), 2);
      f.cancel();
      expect(client.getListenersCount("cache"), 1);
      s.cancel();
      expect(client.getListenersCount("cache"), isNull);
    });
    test("if no listener is there cache should be removed for key", () async {
      final client = RemoterClient(
        options: RemoterOptions(cacheTime: 5000),
      );
      runFakeAsync((async) async {
        // increase listener counts
        final f = client.getStream("cache").listen((event) {});
        await client.fetch<RemoterData<String>, String>(
            "cache", execute: (_) => "result");
        expect(client.getData<RemoterData<String>>("cache")?.data, "result");
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
          options: RemoterOptions(cacheTime: 5000),
        );
        runFakeAsync((async) async {
          // increase listener counts
          final f = client.getStream("cache").listen((event) {});
          await client.fetch<RemoterData<String>, String>(
              "cache", execute: (_) => "result");
          expect(client.getData<RemoterData<String>>("cache")?.data, "result");
          // decrease listener count to start timer
          f.cancel();
          async.elapse(const Duration(milliseconds: 1000));
          // start new listener
          client.getStream("cache").listen((event) {});
          async.elapse(const Duration(milliseconds: 4000));
          expect(client.getData<RemoterData<String>>("cache")?.data, "result");
        });
      },
    );
  });
}
