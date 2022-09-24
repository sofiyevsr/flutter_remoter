import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/src/internals/retry.dart';
import 'package:flutter_remoter/src/internals/types.dart';
import 'package:flutter_remoter/src/widgets/provider.dart';

/// {@template remoter_mutation}
/// Used for fetching remote data, revalidating it and etc.
/// [T] represents type of the value execute function returns
/// [S] represents type of the value passed to mutate function which will be passed to execute function as parameter
///
/// ```dart
///   RemoterMutation<T, S>(
///    execute: (param) async {
///      await Future.delayed(const Duration(seconds: 1));
///    },
///    builder: (context, snapshot, utils) {
///      return Scaffold(
///        body: Center(
///          child: Column(
///            mainAxisAlignment: MainAxisAlignment.center,
///            children: <Widget>[
///              if (snapshot.status == RemoterStatus.fetching)
///                const Text(
///                  'loading...',
///                ),
///              if (snapshot.status == RemoterStatus.error)
///                const Text(
///                  'error occured',
///                ),
///              Text(
///                snapshot.data ?? "idle",
///                style: Theme.of(context).textTheme.headline4,
///              ),
///            ],
///          ),
///        ),
///        floatingActionButton: FloatingActionButton(
///          onPressed: snapshot.status == RemoterStatus.fetching
///              ? null
///              : () {
///                  utils.mutate(null);
///                },
///          child: const Icon(Icons.add),
///        ),
///      );
///   });
///```
/// {@endtemplate}
class RemoterMutation<T, S> extends StatefulWidget {
  /// {@macro remoter_mutation}
  const RemoterMutation({
    super.key,
    this.listener,
    this.maxDelay,
    this.maxRetries,
    required this.execute,
    required this.builder,
  });

  /// Function to fetch data
  final FutureOr<T> Function(S param) execute;

  /// Builder method that is called if data updates
  /// utils is collection of useful methods such as setData, refetch and etc.
  final Widget Function(
    BuildContext context,
    RemoterMutationData<T> snapshot,
    RemoterMutationUtils<T, S> utils,
  ) builder;

  /// Listener function that receives updates of data
  final Function(
    RemoterMutationData<T> oldState,
    RemoterMutationData<T> newState,
  )? listener;

  /// Maximum delay between retries of [execute] function in ms
  /// If omitted falls back to maxDelay of top level [RemoterClient.options]
  final int? maxDelay;

  /// Maximum number of retries running [execute] function
  /// If omitted falls back to maxRetries of top level [RemoterClient.options]
  final int? maxRetries;

  @override
  State<RemoterMutation<T, S>> createState() => _RemoterMutationState<T, S>();
}

class _RemoterMutationState<T, S> extends State<RemoterMutation<T, S>> {
  RemoterMutationData<T> state = RemoterMutationData<T>(data: null);
  late RemoterMutationUtils<T, S> utils = RemoterMutationUtils<T, S>(
    mutate: (param) async {
      final topLevelOptions = RemoterProvider.of(context).client.options;
      try {
        _dispatch(
          RemoterMutationData<T>(
            data: state.data,
            status: RemoterStatus.fetching,
          ),
        );
        final result = await retryFuture(
          () => widget.execute(param),
          maxDelay: widget.maxDelay ?? topLevelOptions.maxDelay.value,
          maxRetries: widget.maxRetries ?? topLevelOptions.maxRetries.value,
        );
        // State was reset, cancel
        if (state.status != RemoterStatus.fetching) return;
        _dispatch(
          RemoterMutationData<T>(
            data: result,
            status: RemoterStatus.success,
          ),
        );
      } catch (error) {
        // State was reset, cancel
        if (state.status != RemoterStatus.fetching) return;
        _dispatch(
          RemoterMutationData<T>(
            data: state.data,
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
    getData: () => state,
  );

  void _dispatch(RemoterMutationData<T> data) {
    setState(() {
      state = data;
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, state, utils);
}
