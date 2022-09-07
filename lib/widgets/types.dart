import 'dart:async';

class RemoterPaginatedUtils<T> {
  final FutureOr Function() fetchNextPage;
  final FutureOr Function() fetchPreviousPage;
  final FutureOr Function() invalidateQuery;
  final FutureOr Function() retry;
  final FutureOr Function(T data) setData;
  RemoterPaginatedUtils({
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.invalidateQuery,
    required this.retry,
    required this.setData,
  });
}

class RemoterQueryUtils<T> {
  final FutureOr Function() invalidateQuery;
  final FutureOr Function() retry;
  final FutureOr Function(T data) setData;
  RemoterQueryUtils({
    required this.invalidateQuery,
    required this.retry,
    required this.setData,
  });
}
