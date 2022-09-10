import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/internals/types.dart';
import 'package:flutter_remoter/widgets/provider.dart';
import 'package:flutter_remoter/widgets/types.dart';

class RemoterQuery<T> extends StatefulWidget {
  final String remoterKey;
  final FutureOr<T> Function() execute;
  final Widget Function(BuildContext, RemoterData<T>, RemoterQueryUtils utils)
      builder;
  final Function(RemoterData<T> oldState, RemoterData<T> newState)? listener;
  final RemoterClientOptions? options;
  final bool? disabled;
  const RemoterQuery({
    super.key,
    this.listener,
    this.options,
    this.disabled,
    required this.remoterKey,
    required this.execute,
    required this.builder,
  });

  @override
  State<RemoterQuery<T>> createState() => RemoterQueryState<T>();
}

class RemoterQueryState<T> extends State<RemoterQuery<T>> {
  bool startupDone = false;
  StreamSubscription<RemoterData<T>>? subscription;
  late RemoterData<T> data;
  late RemoterQueryUtils<RemoterData<T>> utils;

  RemoterQueryUtils<RemoterData<T>> processUtils() {
    final remoter = RemoterProvider.of(context);
    return RemoterQueryUtils<RemoterData<T>>(
      refetch: () => remoter.client.fetch<T>(
        widget.remoterKey,
        (_) => widget.execute(),
        staleTime: widget.options?.staleTime,
        maxDelay: widget.options?.maxDelay,
        maxRetries: widget.options?.maxRetries,
        retryOnMount: widget.options?.retryOnMount,
      ),
      invalidateQuery: () => remoter.client.invalidateQuery<T>(
        widget.remoterKey,
        widget.options?.maxDelay,
        widget.options?.maxRetries,
      ),
      retry: () => remoter.client.retry<T>(
        widget.remoterKey,
        widget.options?.maxDelay,
        widget.options?.maxRetries,
      ),
      setData: (data) =>
          remoter.client.setData<RemoterData<T>>(widget.remoterKey, data),
    );
  }

  RemoterData<T> startStream() {
    subscription?.cancel();
    if (widget.disabled == true) {
      return RemoterData<T>(
        key: widget.remoterKey,
        data: null,
        status: RemoterStatus.idle,
      );
    }
    final provider = RemoterProvider.of(context);
    provider.client.fetch<T>(
      widget.remoterKey,
      (_) => widget.execute(),
      staleTime: widget.options?.staleTime,
      maxDelay: widget.options?.maxDelay,
      maxRetries: widget.options?.maxRetries,
      retryOnMount: widget.options?.retryOnMount,
    );
    subscription = provider.client
        .getStream<RemoterData<T>, T>(
            widget.remoterKey, widget.options?.cacheTime)
        .listen(
      (event) {
        widget.listener?.call(data, event);
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
    if (startupDone == true) return;
    data = startStream();
    utils = processUtils();
    startupDone = true;
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
  Widget build(BuildContext context) => widget.builder(context, data, utils);
}
