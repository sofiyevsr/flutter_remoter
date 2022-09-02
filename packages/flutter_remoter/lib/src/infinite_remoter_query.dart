import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/flutter_remoter.dart';
import 'package:remoter/remoter.dart';

class RemoterInfiniteQuery<T> extends StatefulWidget {
  final String remoterKey;
  final FutureOr<T> Function(RemoterParam?) execute;
  final Widget Function(
    BuildContext,
    InfiniteRemoterData<T>,
    RemoterInfiniteUtils utils,
  ) builder;
  final Function(
          InfiniteRemoterData<T> oldState, InfiniteRemoterData<T> newState)?
      listener;
  final dynamic Function(List<T>)? getNextPageParam;
  final dynamic Function(List<T>)? getPreviousPageParam;
  final RemoterClientOptions? options;
  const RemoterInfiniteQuery({
    super.key,
    this.getPreviousPageParam,
    this.getNextPageParam,
    this.options,
    this.listener,
    required this.remoterKey,
    required this.execute,
    required this.builder,
  });

  @override
  State<RemoterInfiniteQuery<T>> createState() =>
      _InfiniteRemoterQueryState<T>();
}

class _InfiniteRemoterQueryState<T> extends State<RemoterInfiniteQuery<T>> {
  StreamSubscription<InfiniteRemoterData<T>>? subscription;
  late InfiniteRemoterData<T> data;

  InfiniteRemoterData<T> startStream() {
    subscription?.cancel();
    final provider = RemoterProvider.of(context);
    provider.client.saveInfiniteQueryFunctions(
      widget.remoterKey,
      InfiniteQueryFunctions<T>(
        getPreviousPageParam: widget.getPreviousPageParam,
        getNextPageParam: widget.getNextPageParam,
      ),
    );
    provider.client.fetchInfinite<T>(
      widget.remoterKey,
      widget.execute,
      widget.options?.staleTime,
    );
    subscription = provider.client
        .getStream<InfiniteRemoterData<T>, T>(
            widget.remoterKey, widget.options?.cacheTime)
        .listen((event) {
      if (widget.listener != null) widget.listener!(data, event);
      setState(() {
        data = event;
      });
    });
    return provider.client.getData<InfiniteRemoterData<T>>(widget.remoterKey) ??
        InfiniteRemoterData<T>(
          key: widget.remoterKey,
          data: null,
          pageParams: null,
          status: RemoterStatus.fetching,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscription != null) return;
    data = startStream();
  }

  @override
  void didUpdateWidget(RemoterInfiniteQuery<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remoterKey == widget.remoterKey) return;
    final newData = startStream();
    setState(() {
      data = newData;
    });
  }

  @override
  void dispose() {
    super.dispose();
    subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final remoter = RemoterProvider.of(context);
    final utils = RemoterInfiniteUtils<InfiniteRemoterData<T>>(
      fetchNextPage: () => remoter.client.fetchNextPage<T>(widget.remoterKey),
      fetchPreviousPage: () =>
          remoter.client.fetchPreviousPage<T>(widget.remoterKey),
      invalidateQuery: () =>
          remoter.client.invalidateQuery<T>(widget.remoterKey),
      retry: () => remoter.client.retry<T>(widget.remoterKey),
      setData: (data) => remoter.client
          .setData<InfiniteRemoterData<T>>(widget.remoterKey, data),
    );
    return widget.builder(context, data, utils);
  }
}
