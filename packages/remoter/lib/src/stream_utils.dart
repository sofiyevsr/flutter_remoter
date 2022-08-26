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

  void onDone() => _controller.close();

  /// Add [startValue] when user starts to listen
  void onListen() {
    if (startValue == null) return;
    _controller.sink.add(startValue as S);
  }

  /// Allow stream to add onClose callback to sink controller
  /// Because it's not possible to do in StreamTransformer
  void setOnCloseCallback(Function() onClose) {
    _controller.onCancel = () {
      onClose();
      onDone();
    };
  }
}

class CustomStreamTransformer<S> extends StreamTransformerBase<S, S> {
  final CustomSink<S> sink;

  /// Used for decreasing listeners count
  final Function()? onClose;

  /// Used for increasing listeners count
  final Function()? onListen;

  CustomStreamTransformer({required this.sink, this.onClose, this.onListen});

  @override
  Stream<S> bind(Stream<S> stream) {
    StreamSubscription<S>? sub;

    sink.onListen();
    if (onListen != null) onListen!();

    sub = stream.listen(
      sink.onData,
      onError: sink.onError,
      onDone: sink.onDone,
    );

    sink.setOnCloseCallback(() {
      if (onClose != null) onClose!();
      sub?.cancel();
    });

    return sink.stream;
  }
}
