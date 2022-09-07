import 'dart:async';

import 'package:flutter_remoter/internals/stream_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("stream gets latest data on listen", () {
    final controller = StreamController<int>();
    final stream = controller.stream.transform(
      CustomStreamTransformer(sink: CustomSink(10)),
    );
    stream.listen(expectAsync1((value) => expect(value, 10)));
  });
  test("stream is closed when underlying sink does", () {
    final controller = StreamController<int>();
    final sink = CustomSink(10);
    final stream = controller.stream.transform(
      CustomStreamTransformer(sink: sink),
    );
    sink.onDone();
    expect(stream, emitsInOrder([emits(10), emitsDone]));
    expect(sink.closed, true);
  });
}
