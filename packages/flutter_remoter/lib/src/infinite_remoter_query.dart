import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/src/remoter_provider.dart';
import 'package:remoter/remoter.dart';

class InfiniteRemoterQuery<T> extends StatefulWidget {
  final String remoterKey;
  final FutureOr<T> Function(RemoterParam?) execute;
  final Widget Function(BuildContext, InfiniteRemoterData<T>) builder;
  final dynamic Function(List<T>)? getNextPageParam;
  final dynamic Function(List<T>)? getPreviousPageParam;
  final RemoterClientOptions? options;
  const InfiniteRemoterQuery({
    super.key,
    this.getPreviousPageParam,
    this.getNextPageParam,
    this.options,
    required this.remoterKey,
    required this.execute,
    required this.builder,
  });

  @override
  State<InfiniteRemoterQuery<T>> createState() =>
      _InfiniteRemoterQueryState<T>();
}

class _InfiniteRemoterQueryState<T> extends State<InfiniteRemoterQuery<T>> {
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
    provider.client.fetchInfinite(
      widget.remoterKey,
      widget.execute,
      widget.options?.staleTime,
    );
    subscription = provider.client
        .getStream<InfiniteRemoterData<T>, T>(
            widget.remoterKey, widget.options?.cacheTime)
        .listen((event) {
      setState(() {
        data = event;
      });
    });
    return provider.client.getData<InfiniteRemoterData<T>>(widget.remoterKey) ??
        InfiniteRemoterData<T>(
          key: widget.remoterKey,
          data: null,
          pageParams: null,
          status: RemoterStatus.success,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscription != null) return;
    data = startStream();
  }

  @override
  void didUpdateWidget(InfiniteRemoterQuery<T> oldWidget) {
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
    return widget.builder(
      context,
      data,
    );
  }
}
