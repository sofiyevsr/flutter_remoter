import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/src/internals/retry.dart';
import 'package:flutter_remoter/src/internals/types.dart';
import 'package:flutter_remoter/src/widgets/provider.dart';

class RemoterMutation<T, S> extends StatefulWidget {
  /// Function to fetch data
  final FutureOr<T> Function(S param) execute;

  /// Builder method that is called if data updates
  /// utils is collection of useful methods such as setData, refetch and etc.
  final Widget Function(
    BuildContext context,
    RemoterMutationData<T> snapshot,
    RemoterMutationUtils<S> utils,
  ) builder;

  /// Listener function that receives updates of data
  final Function(
    RemoterMutationData<T> oldState,
    RemoterMutationData<T> newState,
  )? listener;

  /// Maximum delay between retries of [execute] function in ms
  final int? maxDelay;

  /// Maximum number of retries running [execute] function
  final int? maxRetries;

  const RemoterMutation({
    super.key,
    this.listener,
    this.maxDelay,
    this.maxRetries,
    required this.execute,
    required this.builder,
  });

  @override
  State<RemoterMutation<T, S>> createState() => _RemoterMutationState<T, S>();
}

class _RemoterMutationState<T, S> extends State<RemoterMutation<T, S>> {
  RemoterMutationData<T> data = RemoterMutationData<T>(data: null);
  late RemoterMutationUtils<S> utils = RemoterMutationUtils<S>(
    mutate: (param) async {
      final topLevelOptions = RemoterProvider.of(context).client.options;
      try {
        _dispatch(
          RemoterMutationData<T>(
            data: null,
            status: RemoterStatus.fetching,
          ),
        );
        final result = await retryFuture(
          () => widget.execute(param),
          maxDelay: widget.maxDelay ?? topLevelOptions.maxDelay.value,
          maxRetries: widget.maxRetries ?? topLevelOptions.maxRetries.value,
        );
        // State was reset, cancel
        if (data.status != RemoterStatus.fetching) return;
        _dispatch(
          RemoterMutationData<T>(
            data: result,
            status: RemoterStatus.success,
          ),
        );
      } catch (error) {
        // State was reset, cancel
        if (data.status != RemoterStatus.fetching) return;
        _dispatch(
          RemoterMutationData<T>(
            data: null,
            status: RemoterStatus.error,
            error: error,
          ),
        );
      }
    },
    reset: () {
      _dispatch(
        RemoterMutationData<T>(data: null),
      );
    },
  );

  void _dispatch(RemoterMutationData<T> data) {
    setState(() {
      this.data = data;
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, data, utils);
}
