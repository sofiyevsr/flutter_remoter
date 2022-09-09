import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/internals/types.dart';
import 'package:flutter_remoter/widgets/provider.dart';
import 'package:flutter_remoter/widgets/types.dart';

class PaginatedRemoterQuery<T> extends StatefulWidget {
  final String remoterKey;
  final FutureOr<T> Function(RemoterParam?) execute;
  final Widget Function(
    BuildContext,
    PaginatedRemoterData<T>,
    RemoterPaginatedUtils utils,
  ) builder;
  final Function(
          PaginatedRemoterData<T> oldState, PaginatedRemoterData<T> newState)?
      listener;
  final dynamic Function(List<T>)? getNextPageParam;
  final dynamic Function(List<T>)? getPreviousPageParam;
  final RemoterClientOptions? options;
  final bool? disabled;
  const PaginatedRemoterQuery({
    super.key,
    this.getPreviousPageParam,
    this.getNextPageParam,
    this.options,
    this.listener,
    this.disabled,
    required this.remoterKey,
    required this.execute,
    required this.builder,
  });

  @override
  State<PaginatedRemoterQuery<T>> createState() =>
      _PaginatedRemoterQueryState<T>();
}

class _PaginatedRemoterQueryState<T> extends State<PaginatedRemoterQuery<T>> {
  bool startupDone = false;
  StreamSubscription<PaginatedRemoterData<T>>? subscription;
  late PaginatedRemoterData<T> data;
  late RemoterPaginatedUtils<PaginatedRemoterData<T>> utils;

  RemoterPaginatedUtils<PaginatedRemoterData<T>> processUtils() {
    final remoter = RemoterProvider.of(context);
    return RemoterPaginatedUtils<PaginatedRemoterData<T>>(
      refetch: () => remoter.client.fetchPaginated<T>(
        widget.remoterKey,
        widget.execute,
        widget.options?.staleTime,
        widget.options?.maxDelay,
        widget.options?.maxAttempts,
      ),
      fetchNextPage: () => remoter.client.fetchNextPage<T>(
        widget.remoterKey,
        widget.options?.maxDelay,
        widget.options?.maxAttempts,
      ),
      fetchPreviousPage: () => remoter.client.fetchPreviousPage<T>(
        widget.remoterKey,
        widget.options?.maxDelay,
        widget.options?.maxAttempts,
      ),
      invalidateQuery: () => remoter.client.invalidateQuery<T>(
        widget.remoterKey,
        widget.options?.maxDelay,
        widget.options?.maxAttempts,
      ),
      retry: () => remoter.client.retry<T>(
        widget.remoterKey,
        widget.options?.maxDelay,
        widget.options?.maxAttempts,
      ),
      setData: (data) => remoter.client
          .setData<PaginatedRemoterData<T>>(widget.remoterKey, data),
    );
  }

  PaginatedRemoterData<T> startStream() {
    subscription?.cancel();
    if (widget.disabled == true) {
      return PaginatedRemoterData<T>(
        key: widget.remoterKey,
        data: null,
        pageParams: null,
        status: RemoterStatus.idle,
      );
    }
    final provider = RemoterProvider.of(context);
    provider.client.savePaginatedQueryFunctions(
      widget.remoterKey,
      PaginatedQueryFunctions<T>(
        getPreviousPageParam: widget.getPreviousPageParam,
        getNextPageParam: widget.getNextPageParam,
      ),
    );
    provider.client.fetchPaginated<T>(
      widget.remoterKey,
      widget.execute,
      widget.options?.staleTime,
      widget.options?.maxDelay,
      widget.options?.maxAttempts,
    );
    subscription = provider.client
        .getStream<PaginatedRemoterData<T>, T>(
            widget.remoterKey, widget.options?.cacheTime)
        .listen((event) {
      widget.listener?.call(data, event);
      setState(() {
        data = event;
      });
    });
    return provider.client
            .getData<PaginatedRemoterData<T>>(widget.remoterKey) ??
        PaginatedRemoterData<T>(
          key: widget.remoterKey,
          data: null,
          pageParams: null,
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
  void didUpdateWidget(PaginatedRemoterQuery<T> oldWidget) {
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
