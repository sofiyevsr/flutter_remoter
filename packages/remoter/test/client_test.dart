import 'package:remoter/src/client.dart';
import 'package:remoter/src/types.dart';
import 'package:test/test.dart';

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
}
