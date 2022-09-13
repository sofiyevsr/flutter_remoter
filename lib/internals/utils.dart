import 'dart:async';
import 'types.dart';

RemoterOptions flattenOptions(
  RemoterOptions topLevelOptions,
  RemoterOptions? options,
) {
  if (options == null) {
    return topLevelOptions;
  }
  final staleTime = options.staleTime.isDefault == false
      ? options.staleTime.value
      : topLevelOptions.staleTime.value;
  final cacheTime = options.cacheTime.isDefault == false
      ? options.cacheTime.value
      : topLevelOptions.cacheTime.value;
  final maxDelay = options.maxDelay.isDefault == false
      ? options.maxDelay.value
      : topLevelOptions.maxDelay.value;
  final maxRetries = options.maxRetries.isDefault == false
      ? options.maxRetries.value
      : topLevelOptions.maxRetries.value;
  final retryOnMount = options.retryOnMount.isDefault == false
      ? options.retryOnMount.value
      : topLevelOptions.retryOnMount.value;
  return RemoterOptions(
    staleTime: staleTime,
    cacheTime: cacheTime,
    maxDelay: maxDelay,
    maxRetries: maxRetries,
    retryOnMount: retryOnMount,
  );
}

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
    onListen?.call();

    sub = stream.listen(
      sink.onData,
      onError: sink.onError,
      onDone: sink.onDone,
    );

    sink.setOnCloseCallback(() {
      onClose?.call();
      sub?.cancel();
    });

    return sink.stream;
  }
}
