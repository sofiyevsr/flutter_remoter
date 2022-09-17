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

class CustomStreamTransformer<S> extends StreamTransformerBase<S, S> {
  /// Used for decreasing listeners count
  final Function()? onClose;

  /// Used for increasing listeners count
  final Function()? onListen;

  CustomStreamTransformer({this.onClose, this.onListen});

  @override
  Stream<S> bind(Stream<S> stream) {
    final controller = StreamController<S>();
    StreamSubscription<S>? sub;

    controller.onListen = onListen;
    controller.onCancel = () {
      controller.close();
      onClose?.call();
      sub?.cancel();
    };

    sub = stream.listen(
      controller.sink.add,
      onError: controller.sink.addError,
      onDone: controller.close,
    );

    return controller.stream;
  }
}
