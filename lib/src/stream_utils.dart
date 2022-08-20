import 'dart:async';

/// Stream transformer that starts with [startValue]
class CustomSink<S> {
  final S? startValue;
  late final StreamController<S> _controller;

  CustomSink(this.startValue) {
    _controller = StreamController<S>();
  }

  Stream<S> get stream => _controller.stream;
  bool get closed => _controller.isClosed;

  void onData(S data) {
    _controller.sink.add(data);
  }

  void onError(Object error, StackTrace stack) =>
      _controller.sink.addError(error, stack);

  void onDone() => _controller.sink.close();

  void onListen() {
    if (startValue == null) return;
    _controller.sink.add(startValue as S);
  }

  void setOnCloseCallback(Function() onClose) {
    _controller.onCancel = onClose;
  }
}

class CustomStreamTransformer<S> extends StreamTransformerBase<S, S> {
  final CustomSink<S> sink;

  CustomStreamTransformer({required this.sink});

  @override
  Stream<S> bind(Stream<S> stream) {
    StreamSubscription<S>? sub;

    sink.onListen();

    sub = stream.listen(
      sink.onData,
      onError: sink.onError,
      onDone: sink.onDone,
    );

    sink.setOnCloseCallback(() {
      sub?.cancel();
    });

    return sink.stream;
  }
}
