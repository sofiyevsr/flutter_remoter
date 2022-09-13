import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/internals/types.dart';
import 'package:flutter_remoter/widgets/provider.dart';

/// Used for data that has multiple pages or "infinite scroll" like experience.
/// If [T] generic is used, all [RemoterClient] method calls should be called with [T],
/// otherwise runtime type casting error will be thrown
///
/// ```dart
/// PaginatedRemoterQuery<T>(
///       remoterKey: "key",
///       getNextPageParam: (pages) {
///         return pages[pages.length - 1].nextPage;
///       },
///       getPreviousPageParam: (pages) {
///         return pages[0].previousPage;
///       },
///       execute: (param) async {
///         // Fetch data here
///       },
///       listener: (oldState, newState) async {
///         // Optional state listener
///       },
///       builder: (context, snapshot, utils) {
///         if (snapshot.status == RemoterStatus.idle) {
///           // You can skip this check if you don't use disabled parameter
///         }
///         if (snapshot.status == RemoterStatus.fetching) {
///           // Handle fetching state here
///         }
///         if (snapshot.status == RemoterStatus.error) {
///           // Handle error here
///         }
///         // It is okay to use snapshot.data! here
///         return ...
///       })
///```
class PaginatedRemoterQuery<T> extends StatefulWidget {
  /// Unique identifier for query
  final String remoterKey;

  /// Function to fetch data, receives parameter of [RemoterParam] which is data returned from [getNextPageParam] or [getPreviousPageParam]
  final FutureOr<T> Function(RemoterParam? param) execute;

  /// Builder method that is called if data updates
  /// utils is collection of useful methods such as fetchNextPage, fetchPreviousPage and etc.
  final Widget Function(
    BuildContext context,
    PaginatedRemoterData<T> snapshot,
    RemoterPaginatedUtils utils,
  ) builder;

  /// Listener function that receives updates of data
  final Function(
    PaginatedRemoterData<T> oldState,
    PaginatedRemoterData<T> newState,
  )? listener;

  /// Function receives current pages array and returns dynamic value which will be passed to [execute]
  /// Returning null means no more next page is available
  final dynamic Function(List<T>)? getNextPageParam;

  /// Function receives current pages array and returns dynamic value which will be passed to [execute]
  /// Returning null means no more previous page is available
  final dynamic Function(List<T>)? getPreviousPageParam;

  /// Options that will be applied to only this query
  /// Omitted values in options will still fallback to top level options
  final RemoterOptions? options;

  /// Query won't start executing if [disabled] is true
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
        widget.options,
      ),
      fetchNextPage: () => remoter.client.fetchNextPage<T>(
        widget.remoterKey,
        widget.options,
      ),
      fetchPreviousPage: () => remoter.client.fetchPreviousPage<T>(
        widget.remoterKey,
        widget.options,
      ),
      invalidateQuery: () => remoter.client.invalidateQuery<T>(
        widget.remoterKey,
        widget.options,
      ),
      retry: () => remoter.client.retry<T>(
        widget.remoterKey,
        widget.options,
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
      widget.options,
    );
    subscription = provider.client
        .getStream<PaginatedRemoterData<T>, T>(
      widget.remoterKey,
      widget.options,
    )
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
