import 'package:remoter/remoter.dart';
import 'package:test/test.dart';

void main() {
  test("set query data", () async {
    final client = RemoterClient();
    final stream =
        client.getStream<InfiniteRemoterData<String>, String>("cache");
    client.setData(
      "cache",
      InfiniteRemoterData<String>(
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
    await client.fetchInfinite<String>("cache", (_) {
      if (pass == true) {
        return "new";
      }
      pass = true;
      return "stale";
    });
    // Required to be able to invalidate
    client.getStream("cache");
    expect(client.getData("cache")?.data, ["stale"]);
    await client.invalidateQuery<String>("cache");
    expect(client.getData("cache")?.data, ["new"]);
  });

  test("fetching previous page", () async {
    final client = RemoterClient();
    client.saveInfiniteQueryFunctions(
      "cache",
      InfiniteQueryFunctions(getPreviousPageParam: (pages) => "previous"),
    );
    await client.fetchInfinite<String>("cache", (param) {
      return param?.value ?? "default";
    });
    expect(client.getData("cache")?.data, ["default"]);
    await client.fetchPreviousPage<String>("cache");
    expect(client.getData("cache")?.data, ["previous", "default"]);
  });

  test("fetching next page", () async {
    final client = RemoterClient();
    client.saveInfiniteQueryFunctions(
      "cache",
      InfiniteQueryFunctions(getNextPageParam: (pages) => "next"),
    );
    await client.fetchInfinite<String>("cache", (param) {
      return param?.value ?? "default";
    });
    expect(client.getData("cache")?.data, ["default"]);
    await client.fetchNextPage<String>("cache");
    expect(client.getData("cache")?.data, ["default", "next"]);
  });

  test("if getNextPageParam returns null hasNextPage should be null", () async {
    final client = RemoterClient();
    int? page = 1;
    client.saveInfiniteQueryFunctions(
      "cache",
      InfiniteQueryFunctions(getNextPageParam: (pages) {
        final temp = page;
        page = null;
        return temp;
      }),
    );
    await client.fetchInfinite<String>("cache", (param) {
      return "default";
    });
    expect(
      client.getData<InfiniteRemoterData<String>>("cache")?.hasNextPage,
      true,
    );
    await client.fetchNextPage<String>("cache");
    expect(
      client.getData<InfiniteRemoterData<String>>("cache")?.hasNextPage,
      false,
    );
  });

  test("if getPreviousPageParam returns null hasPreviousPage should be null",
      () async {
    final client = RemoterClient();
    int? page = 1;
    client.saveInfiniteQueryFunctions(
      "cache",
      InfiniteQueryFunctions(getPreviousPageParam: (pages) {
        final temp = page;
        page = null;
        return temp;
      }),
    );
    await client.fetchInfinite<String>("cache", (param) {
      return "default";
    });
    expect(
      client.getData<InfiniteRemoterData<String>>("cache")?.hasPreviousPage,
      true,
    );
    await client.fetchPreviousPage<String>("cache");
    expect(
      client.getData<InfiniteRemoterData<String>>("cache")?.hasPreviousPage,
      false,
    );
  });
}
