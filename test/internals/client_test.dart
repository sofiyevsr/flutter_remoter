import 'package:flutter_remoter/internals/client.dart';
import 'package:flutter_remoter/internals/types.dart';
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

  group("if fetch api fails should increase failcount", () {
    test("RemoterQuery", () async {
      final client = RemoterClient();
      int count = 0;
      runFakeAsync((time) async {
        await client.fetch<RemoterData<String>, String>(
          "cache",
          execute: (_) async {
            count += 1;
            throw Error();
          },
          options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 3),
        );
        time.elapse(const Duration(seconds: 0));
        final data = client.getData<RemoterData<String>>("cache");
        expect(data?.status, RemoterStatus.error);
        expect(data?.failCount, 3);
        expect(count, 3);
      });
    });
    test("PaginatedRemoterQuery", () async {
      final client = RemoterClient();
      int count = 0;
      runFakeAsync((time) async {
        await client.fetch<PaginatedRemoterData<String>, String>(
          "cache",
          execute: (_) async {
            count += 1;
            throw Error();
          },
          options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 3),
        );
        time.elapse(const Duration(seconds: 0));
        final data = client.getData<PaginatedRemoterData<String>>("cache");
        expect(data?.status, RemoterStatus.error);
        expect(data?.failCount, 3);
        expect(count, 3);
      });
    });
  });

  group("stream should receive status of fetching and failcount while retrying",
      () {
    test("RemoterQuery", () {
      final client = RemoterClient();
      final stream = client.getStream<RemoterData<String>, String>("cache");
      int count = 0;
      runFakeAsync((time) async {
        await client.fetch<RemoterData<String>, String>(
          "cache",
          execute: (_) async {
            count += 1;
            if (count == 3) return "result";
            throw Error();
          },
          options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 3),
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
              expect(d.failCount, 2);
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
    test("PaginatedRemoterQuery", () {
      final client = RemoterClient();
      final stream =
          client.getStream<PaginatedRemoterData<String>, String>("cache");
      int count = 0;
      runFakeAsync((time) async {
        await client.fetch<PaginatedRemoterData<String>, String>(
          "cache",
          execute: (_) async {
            count += 1;
            if (count == 3) return "result";
            throw Error();
          },
          options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 3),
        );
        time.elapse(const Duration(seconds: 0));
        client.dispose();
        expectLater(
          stream,
          emitsInOrder([
            predicate<PaginatedRemoterData<String>>((d) {
              expect(d.failCount, 1);
              expect(d.status, RemoterStatus.fetching);
              return true;
            }),
            predicate<PaginatedRemoterData<String>>((d) {
              expect(d.failCount, 2);
              expect(d.status, RemoterStatus.fetching);
              return true;
            }),
            predicate<PaginatedRemoterData<String>>((d) {
              expect(d.data, ["result"]);
              expect(d.status, RemoterStatus.success);
              return true;
            }),
            emitsDone,
          ]),
        );
      });
    });
  });

  group("fetching failed query should trigger retry", () {
    test("RemoterQuery", () {
      final client = RemoterClient();
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
          options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 3),
        );
        time.elapse(const Duration(seconds: 0));
        expect(client.getData<RemoterData<String>>("cache")?.data, null);
        await client.fetch<RemoterData<String>, String>(
          "cache",
          execute: (_) => getData(false),
          options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 3),
        );
        expect(client.getData<RemoterData<String>>("cache")?.data, "result");
      });
    });
    test("PaginatedRemoterQuery", () {
      final client = RemoterClient();
      Future<String> getData(bool fail) async {
        if (fail == true) {
          throw Error();
        }
        return "result";
      }

      runFakeAsync((time) async {
        await client.fetch<PaginatedRemoterData<String>, String>(
          "cache",
          execute: (_) => getData(true),
          options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 3),
        );
        time.elapse(const Duration(seconds: 0));
        expect(
            client.getData<PaginatedRemoterData<String>>("cache")?.data, null);
        await client.fetch<PaginatedRemoterData<String>, String>(
          "cache",
          execute: (_) => getData(false),
          options: RemoterOptions(staleTime: 0, maxDelay: 0, maxRetries: 3),
        );
        expect(client.getData<PaginatedRemoterData<String>>("cache")?.data,
            ["result"]);
      });
    });
  });
}
