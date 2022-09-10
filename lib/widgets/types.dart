import 'dart:async';

import 'package:flutter_remoter/internals/types.dart';

abstract class RemoterUtils<T> {
  final FutureOr Function() invalidateQuery;
  final FutureOr Function() retry;
  final FutureOr Function() refetch;
  final FutureOr Function(T data) setData;
  RemoterUtils({
    required this.invalidateQuery,
    required this.retry,
    required this.setData,
    required this.refetch,
  });
}

class RemoterPaginatedUtils<T> extends RemoterUtils<T> {
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

class RemoterQueryUtils<T> extends RemoterUtils<T> {
  RemoterQueryUtils({
    required super.invalidateQuery,
    required super.retry,
    required super.setData,
    required super.refetch,
  });
}

class RemoterMutationData<T> {
  Object? error;
  T? data;
  RemoterStatus status;
  RemoterMutationData({
    required this.data,
    required this.status,
    this.error,
  });
}
