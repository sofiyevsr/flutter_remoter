import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/src/provider.dart';
import 'package:flutter_remoter/src/types.dart';
import 'package:remoter/remoter.dart';

class RemoterQuery<T> extends StatefulWidget {
  final String remoterKey;
  final FutureOr<T> Function() execute;
  final Widget Function(BuildContext, RemoterData<T>, RemoterQueryUtils utils)
      builder;
  final Function(RemoterData<T> oldState, RemoterData<T> newState)? listener;
  final RemoterClientOptions? options;
  const RemoterQuery({
    super.key,
    this.listener,
    this.options,
    required this.remoterKey,
    required this.execute,
    required this.builder,
  });

  @override
  State<RemoterQuery<T>> createState() => RemoterQueryState<T>();
}

class RemoterQueryState<T> extends State<RemoterQuery<T>> {
  StreamSubscription<RemoterData<T>>? subscription;
  late RemoterData<T> data;
  late RemoterQueryUtils<RemoterData<T>> utils;

  RemoterQueryUtils<RemoterData<T>> processUtils() {
    final remoter = RemoterProvider.of(context);
    return RemoterQueryUtils<RemoterData<T>>(
      invalidateQuery: () =>
          remoter.client.invalidateQuery<T>(widget.remoterKey),
      retry: () => remoter.client.retry<T>(widget.remoterKey),
      setData: (data) =>
          remoter.client.setData<RemoterData<T>>(widget.remoterKey, data),
    );
  }

  RemoterData<T> startStream() {
    subscription?.cancel();
    final provider = RemoterProvider.of(context);
    provider.client.fetch<T>(
      widget.remoterKey,
      (_) => widget.execute(),
      widget.options?.staleTime,
    );
    subscription = provider.client
        .getStream<RemoterData<T>, T>(
            widget.remoterKey, widget.options?.cacheTime)
        .listen(
      (event) {
        if (widget.listener != null) widget.listener!(data, event);
        setState(() {
          data = event;
        });
      },
    );
    return provider.client.getData<RemoterData<T>>(widget.remoterKey) ??
        RemoterData<T>(
          key: widget.remoterKey,
          data: null,
          status: RemoterStatus.fetching,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscription != null) return;
    data = startStream();
    utils = processUtils();
  }

  @override
  void didUpdateWidget(RemoterQuery<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newData = startStream();
    final newUtils = processUtils();
    setState(() {
      data = newData;
      utils = newUtils;
    });
  }

  @override
  void dispose() {
    super.dispose();
    subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      data,
      utils,
    );
  }
}