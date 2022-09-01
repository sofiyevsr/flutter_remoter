import 'package:remoter/remoter.dart';
import 'package:test/test.dart';

void main() {
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
}
