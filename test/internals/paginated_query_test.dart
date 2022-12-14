import 'package:flutter_remoter/src/internals/client.dart';
import 'package:flutter_remoter/src/internals/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("set query data", () async {
    final client = RemoterClient();
    final stream =
        client.getStream<PaginatedRemoterData<String>, String>("cache");
    client.setData(
      "cache",
      PaginatedRemoterData<String>(
        key: "cache",
        data: ["result"],
        status: RemoterStatus.success,
        pageParams: [],
      ),
    );
    stream.listen(expectAsync1((value) => expect(value.data, ["result"])));
  });

  test("invalidate query works", () async {
    final client = RemoterClient();
    bool pass = false;
    await client.fetch<PaginatedRemoterData<String>, String>("cache",
        execute: (_) {
      if (pass == true) {
        return "new";
      }
      pass = true;
      return "stale";
    });
    // Required to be able to invalidate
    client.getStream("cache").listen((event) {});
    expect(client.getData("cache")?.data, ["stale"]);
    await client.invalidateQuery<String>("cache");
    expect(client.getData("cache")?.data, ["new"]);
  });

  test("fetching previous page", () async {
    final client = RemoterClient();
    client.savePaginatedQueryFunctions(
      "cache",
      PaginatedQueryFunctions<String>(
          getPreviousPageParam: (pages) => "previous"),
    );
    await client.fetch<PaginatedRemoterData<String>, String>("cache",
        execute: (param) {
      return param?.value ?? "default";
    });
    expect(client.getData("cache")?.data, ["default"]);
    await client.fetchPreviousPage<String>("cache");
    expect(client.getData("cache")?.data, ["previous", "default"]);
  });

  test("fetching next page", () async {
    final client = RemoterClient();
    client.savePaginatedQueryFunctions(
      "cache",
      PaginatedQueryFunctions<String>(getNextPageParam: (pages) => "next"),
    );
    await client.fetch<PaginatedRemoterData<String>, String>("cache",
        execute: (param) {
      return param?.value ?? "default";
    });
    expect(client.getData("cache")?.data, ["default"]);
    await client.fetchNextPage<String>("cache");
    expect(client.getData("cache")?.data, ["default", "next"]);
  });

  test("fetching both next and prev page is okay", () async {
    final client = RemoterClient();
    client.savePaginatedQueryFunctions(
      "cache",
      PaginatedQueryFunctions<String>(
          getNextPageParam: (pages) => "next",
          getPreviousPageParam: (pages) => "prev"),
    );
    await client.fetch<PaginatedRemoterData<String>, String>("cache",
        execute: (param) {
      return param?.value ?? "default";
    });
    await Future.wait([
      client.fetchNextPage<String>("cache"),
      client.fetchPreviousPage<String>("cache"),
    ]);
    expect(client.getData("cache")?.data, ["prev", "default", "next"]);
  });

  test("if getNextPageParam returns null hasNextPage should be null", () async {
    final client = RemoterClient();
    int? page = 1;
    client.savePaginatedQueryFunctions(
      "cache",
      PaginatedQueryFunctions<String>(getNextPageParam: (pages) {
        final temp = page;
        page = null;
        return temp;
      }),
    );
    await client.fetch<PaginatedRemoterData<String>, String>("cache",
        execute: (param) {
      return "default";
    });
    expect(
      client.getData<PaginatedRemoterData<String>>("cache")?.hasNextPage,
      true,
    );
    await client.fetchNextPage<String>("cache");
    expect(
      client.getData<PaginatedRemoterData<String>>("cache")?.hasNextPage,
      false,
    );
  });

  test("if getPreviousPageParam returns null hasPreviousPage should be null",
      () async {
    final client = RemoterClient();
    int? page = 1;
    client.savePaginatedQueryFunctions(
      "cache",
      PaginatedQueryFunctions<String>(getPreviousPageParam: (pages) {
        final temp = page;
        page = null;
        return temp;
      }),
    );
    await client.fetch<PaginatedRemoterData<String>, String>("cache",
        execute: (param) {
      return "default";
    });
    expect(
      client.getData<PaginatedRemoterData<String>>("cache")?.hasPreviousPage,
      true,
    );
    await client.fetchPreviousPage<String>("cache");
    expect(
      client.getData<PaginatedRemoterData<String>>("cache")?.hasPreviousPage,
      false,
    );
  });
}
