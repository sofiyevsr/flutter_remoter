class RemoterInfiniteUtils {
  final Function() fetchNextPage;
  final Function() fetchPreviousPage;
  final Function() invalidateQuery;
  RemoterInfiniteUtils({
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.invalidateQuery,
  });
}
