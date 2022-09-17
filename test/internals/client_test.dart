import 'package:flutter_remoter/src/internals/client.dart';
import 'package:flutter_remoter/src/internals/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/run_fake_async.dart';

void main() {
  test("stream receives only given key's data", () async {
    final client = RemoterClient();
    final stream = client.getStream<RemoterData<String>, String>("cache");
    client.setData(
        "non-cache", RemoterData<String>(key: "non-cache", data: "non-result"));
    client.setData("cache", RemoterData<String>(key: "cache", data: "result"));
    client.dispose();
    expectLater(
      stream,
      emitsInOrder([
        predicate<RemoterData<String>>((d) {
          expect(d.data, "result");
          return true;
        }),
        emitsDone,
      ]),
    );
  });

  test("if fetch api fails should increase failcount", () async {
    final client = RemoterClient(
      options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 3),
    );
    runFakeAsync((time) async {
      await client.fetch<RemoterData<String>, String>(
        "cache",
        execute: (_) async {
          throw Error();
        },
      );
      time.elapse(const Duration(seconds: 0));
      final data = client.getData<RemoterData<String>>("cache");
      expect(data?.status, RemoterStatus.error);
      expect(data?.failCount, 4);
    });
  });

  test("stream should receive status of fetching and failcount while retrying",
      () {
    final client = RemoterClient();
    final stream = client.getStream<RemoterData<String>, String>("cache");
    int count = 0;
    runFakeAsync((time) async {
      await client.fetch<RemoterData<String>, String>(
        "cache",
        execute: (_) async {
          count += 1;
          if (count == 2) return "result";
          throw Error();
        },
        options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 1),
      );
      time.elapse(const Duration(seconds: 0));
      client.dispose();
      expectLater(
        stream,
        emitsInOrder([
          predicate<RemoterData<String>>((d) {
            expect(d.failCount, 1);
            expect(d.status, RemoterStatus.fetching);
            return true;
          }),
          predicate<RemoterData<String>>((d) {
            expect(d.data, "result");
            expect(d.status, RemoterStatus.success);
            return true;
          }),
          emitsDone,
        ]),
      );
    });
  });

  test("fetching failed query should trigger retry", () {
    final client = RemoterClient(options: RemoterOptions(maxRetries: 0));
    Future<String> getData(bool fail) async {
      if (fail == true) {
        throw Error();
      }
      return "result";
    }

    runFakeAsync((time) async {
      await client.fetch<RemoterData<String>, String>(
        "cache",
        execute: (_) => getData(true),
      );
      time.elapse(const Duration(seconds: 0));
      expect(
        client.getData<RemoterData<String>>("cache")?.status,
        RemoterStatus.error,
      );
      await client.fetch<RemoterData<String>, String>(
        "cache",
        execute: (_) => getData(false),
      );
      expect(client.getData<RemoterData<String>>("cache")?.data, "result");
    });
  });

  test("only fetching stale query should trigger backgroud refetch", () {
    final client = RemoterClient(
      options: RemoterOptions(staleTime: 1000),
    );
    int count = 0;
    Future<String> getData() async {
      count++;
      return count.toString();
    }

    runFakeAsync((time) async {
      await client.fetch<RemoterData<String>, String>(
        "cache",
        execute: (_) => getData(),
      );
      expect(client.getData<RemoterData<String>>("cache")?.data, "1");
      time.elapse(
        const Duration(milliseconds: 100),
      );
      expect(client.getData<RemoterData<String>>("cache")?.data, "1");
      time.elapse(
        const Duration(milliseconds: 900),
      );
      await client.fetch<RemoterData<String>, String>("cache");
      expect(client.getData<RemoterData<String>>("cache")?.data, "2");
    });
  });
}
