import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/src/internals/types.dart';
import 'package:flutter_remoter/src/widgets/provider.dart';

/// Used for fetching remote data, revalidating it and etc.
/// If [T] generic is used, all [RemoterClient] method calls should be called with [T],
/// otherwise runtime type casting error will be thrown
///
/// ```dart
/// RemoterQuery<T>(
///       remoterKey: "key",
///       listener: (oldState, newState) async {
///         // Optional state listener
///       },
///       execute: (param) async {
///         // Fetch data here
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
class RemoterQuery<T> extends StatefulWidget {
  /// Unique identifier for query
  final String remoterKey;

  /// Function to fetch data
  final FutureOr<T> Function() execute;

  /// Builder method that is called if data updates
  /// utils is collection of useful methods such as setData, refetch and etc.
  final Widget Function(
    BuildContext context,
    RemoterData<T> snapshot,
    RemoterQueryUtils<RemoterData<T>> utils,
  ) builder;

  /// Listener function that receives updates of data
  final Function(RemoterData<T> oldState, RemoterData<T> newState)? listener;

  /// Options that will be applied to only this query
  /// Omitted values in options will still fallback to top level options
  final RemoterOptions? options;

  /// Query won't start executing if [disabled] is true
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
      refetch: () => remoter.client.fetch<RemoterData<T>, T>(
        widget.remoterKey,
        options: widget.options,
      ),
      invalidateQuery: () => remoter.client.invalidateQuery<T>(
        widget.remoterKey,
        widget.options,
      ),
      retry: () => remoter.client.retry<T>(
        widget.remoterKey,
        widget.options,
      ),
      getData: () => data,
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
    provider.client.fetch<RemoterData<T>, T>(
      widget.remoterKey,
      execute: (_) => widget.execute(),
      options: widget.options,
    );
    subscription = provider.client
        .getStream<RemoterData<T>, T>(
      widget.remoterKey,
      widget.options,
    )
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
