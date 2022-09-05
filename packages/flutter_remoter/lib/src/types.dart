class RemoterPaginatedUtils<T> {
  final Function() fetchNextPage;
  final Function() fetchPreviousPage;
  final Function() invalidateQuery;
  final Function() retry;
  final Function(T data) setData;
  RemoterPaginatedUtils({
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.invalidateQuery,
    required this.retry,
    required this.setData,
  });
}

class RemoterQueryUtils<T> {
  final Function() invalidateQuery;
  final Function() retry;
  final Function(T data) setData;
  RemoterQueryUtils({
    required this.invalidateQuery,
    required this.retry,
    required this.setData,
  });
}
