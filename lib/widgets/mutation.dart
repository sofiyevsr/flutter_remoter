import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/internals/retry.dart';
import 'package:flutter_remoter/internals/types.dart';
import 'package:flutter_remoter/widgets/provider.dart';
import 'package:flutter_remoter/widgets/types.dart';

class RemoterMutation<T, S> extends StatefulWidget {
  /// Function to fetch data
  final FutureOr<T> Function(S param) execute;

  /// Builder method that is called if data updates
  /// utils is collection of useful methods such as setData, refetch and etc.
  final Widget Function(
    BuildContext context,
    RemoterMutationData<T> snapshot,
    RemoterMutationUtils utils,
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
        _dispatch(
          RemoterMutationData<T>(
            data: result,
            status: RemoterStatus.success,
          ),
        );
      } catch (error) {
        _dispatch(
          RemoterMutationData(
            data: null,
            status: RemoterStatus.error,
            error: error,
          ),
        );
      }
    },
    reset: () {
      _dispatch(
        RemoterMutationData(data: null),
      );
    },
  );

  void _dispatch(RemoterMutationData data) {
    setState(() {
      data = data;
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, data, utils);
}
