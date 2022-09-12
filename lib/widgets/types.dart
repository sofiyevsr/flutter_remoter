import 'dart:async';
import 'package:flutter_remoter/internals/types.dart';

/// Represents class of helper methods which is passed to builder function for [RemoterQuery]
/// These function doesn't add any functionality to [RemoterClient] methods
class RemoterQueryUtils<T> {
  final FutureOr Function() invalidateQuery;
  final FutureOr Function() retry;
  final FutureOr Function() refetch;
  final FutureOr Function(T data) setData;
  RemoterQueryUtils({
    required this.invalidateQuery,
    required this.retry,
    required this.setData,
    required this.refetch,
  });
}

/// Represents class of helper methods which is passed to builder function for [PaginatedRemoterQuery]
/// These function doesn't add any functionality to [RemoterClient] methods
class RemoterPaginatedUtils<T> extends RemoterQueryUtils<T> {
  final FutureOr Function() fetchNextPage;
  final FutureOr Function() fetchPreviousPage;
  RemoterPaginatedUtils({
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required super.invalidateQuery,
    required super.retry,
    required super.setData,
    required super.refetch,
  });
}

/// Represents class for helper methods which is passed to builder function for [RemoterMutation]
class RemoterMutationUtils<S> {
  final FutureOr Function() reset;
  final FutureOr Function(S param) mutate;
  RemoterMutationUtils({
    required this.mutate,
    required this.reset,
  });
}

class RemoterMutationData<T> {
  Object? error;
  T? data;
  RemoterStatus status;
  RemoterMutationData({
    required this.data,
    this.status = RemoterStatus.idle,
    this.error,
  });
}
