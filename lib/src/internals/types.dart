import 'dart:async';

import 'package:clock/clock.dart';

/// {@template remoter_options}
/// Defines options for [RemoterClient], [RemoterQuery] and [PaginatedRemoterQuery]
///
/// ```dart
/// RemoterOptions(
///       // staleTime defines how many ms after query fetched can be refetched
///       staleTime: 0,
///       // cacheTime defines how many ms after all listeners are gone query data should be cleared,
///       cacheTime: 5 * 60 * 1000,
///       // Maximum delay between retries in ms
///       maxDelay: 5 * 60 * 1000,
///       // Maximum amount of retries
///       maxRetries: 3,
///       // Flag that decides if query that has error status should be refetched on mount
///       retryOnMount: true,
/// )
/// ```
/// {@endtemplate}
class RemoterOptions {
  /// {@macro remoter_options}
  RemoterOptions({
    int? staleTime,
    int? cacheTime,
    int? maxDelay,
    int? maxRetries,
    bool? retryOnMount,
  })  : staleTime = staleTime != null
            ? Default(staleTime, isDefault: false)
            : Default(0),
        cacheTime = cacheTime != null
            ? Default(cacheTime, isDefault: false)
            : Default(5 * 1000 * 60),
        maxDelay = maxDelay != null
            ? Default(maxDelay, isDefault: false)
            : Default(5 * 1000 * 60),
        maxRetries = maxRetries != null
            ? Default(maxRetries, isDefault: false)
            : Default(3),
        retryOnMount = retryOnMount != null
            ? Default(retryOnMount, isDefault: false)
            : Default(true);

  /// Defines after how many ms after query data is considered as stale
  final Default<int> staleTime;

  /// Defines after how many ms after all listeners unmounted cache should be cleared
  final Default<int> cacheTime;

  /// Maximum delay between retries in ms
  final Default<int> maxDelay;

  /// Maximum amount of retries
  final Default<int> maxRetries;

  /// Flag that decides if query that has error status should be refetched on mount
  final Default<bool> retryOnMount;
}

/// Represents status for query
/// [idle] is used only if query is disabled
enum RemoterStatus {
  idle,
  fetching,
  success,
  error,
}

/// Used to determine [RemoterParam] type
enum RemoterParamType {
  previous,
  next,
}

/// {@template remoter_param}
/// Represents parameter object passed to [PaginatedRemoterQuery.execute]
/// {@endtemplate}
class RemoterParam<T> {
  /// {@macro remoter_param}
  RemoterParam({required this.value, required this.type});

  RemoterParamType type;
  T value;
}

/// {@template base_remoter_data}
/// Represents abstraction for [RemoterData] and [PaginatedRemoterData]
/// {@endtemplate}
abstract class BaseRemoterData<T> {
  /// {@macro base_remoter_data}
  BaseRemoterData({
    required this.key,
    this.error,
    bool? isRefetching,
    RemoterStatus? status,
    DateTime? updatedAt,
    int? failCount,
  })  : updatedAt = updatedAt ?? clock.now(),
        isRefetching = isRefetching ?? false,
        status = status ?? RemoterStatus.idle,
        failCount = failCount ?? 0;

  /// Unique identifier of data
  String key;

  /// Represents state of data, default [RemoterStatus.idle]
  RemoterStatus status;

  /// Represents last time data is updated, default now
  DateTime updatedAt;

  /// True if query refetch is in progress, default false
  bool isRefetching;

  /// Represents error object if status is [RemoterStatus.error]
  /// also can be non-null if next or previous page fetch fails
  Object? error;

  /// Represents how many times execute function failed while fetching this query, default 0
  final int failCount;

  BaseRemoterData copyWith({
    String? key,
    Nullable<Object>? error,
    Nullable<DateTime>? updatedAt,
    Nullable<RemoterStatus>? status,
    Nullable<bool>? isRefetching,
    Nullable<int>? failCount,
  });

  @override
  String toString() {
    return "BaseRemoteData -> key: $key, status: $status, error: $error, updatedAt: $updatedAt";
  }
}

/// {@template remoter_data}
/// Represents data fetched for [RemoterQuery]
/// [T] represents the type of data fetched in the query
/// {@endtemplate}
class RemoterData<T> extends BaseRemoterData<T> {
  /// {@macro remoter_data}
  RemoterData({
    required super.key,
    required this.data,
    super.updatedAt,
    super.error,
    super.status,
    super.isRefetching,
    super.failCount,
  });

  /// Represents data execute function returns on [RemoterStatus.success]
  final T? data;

  @override
  RemoterData<T> copyWith({
    String? key,
    Nullable<T>? data,
    Nullable<Object>? error,
    Nullable<DateTime>? updatedAt,
    Nullable<RemoterStatus>? status,
    Nullable<bool>? isRefetching,
    Nullable<int>? failCount,
  }) =>
      RemoterData<T>(
        key: key ?? this.key,
        data: data == null ? this.data : data.value,
        error: error == null ? this.error : error.value,
        updatedAt: updatedAt == null ? this.updatedAt : updatedAt.value,
        status: status == null ? this.status : status.value,
        isRefetching:
            isRefetching == null ? this.isRefetching : isRefetching.value,
        failCount: failCount == null ? this.failCount : failCount.value,
      );
}

/// {@template paginated_remoter_data}
/// Represents data fetched for [PaginatedRemoterQuery]
/// [T] represents the type of data in list of pages fetched in the query
/// {@endtemplate}
class PaginatedRemoterData<T> extends BaseRemoterData<T> {
  /// {@macro paginated_remoter_data}
  PaginatedRemoterData({
    required super.key,
    required this.data,
    required this.pageParams,
    super.updatedAt,
    super.error,
    super.status,
    super.isRefetching,
    super.failCount,
    int? prevPageFailCount,
    int? nextPageFailCount,
    bool? isFetchingPreviousPage,
    bool? isFetchingNextPage,
    bool? isPreviousPageError,
    bool? isNextPageError,
    bool? hasPreviousPage,
    bool? hasNextPage,
  })  : isFetchingPreviousPage = isFetchingPreviousPage ?? false,
        isFetchingNextPage = isFetchingNextPage ?? false,
        isPreviousPageError = isPreviousPageError ?? false,
        isNextPageError = isNextPageError ?? false,
        hasPreviousPage = hasPreviousPage ?? false,
        hasNextPage = hasNextPage ?? false,
        prevPageFailCount = prevPageFailCount ?? 0,
        nextPageFailCount = nextPageFailCount ?? 0;

  /// Stores parameters used to call fetch function with
  final List<RemoterParam?>? pageParams;

  /// Represents data in list of pages
  /// execute function returns based on [pageParams] on [RemoterStatus.success]
  final List<T>? data;

  /// Represents how many times execute function failed while fetching previous page, default 0
  final int prevPageFailCount;

  /// Represents how many times execute function failed while fetching next page, default 0
  final int nextPageFailCount;

  /// Represents if currently fetching previous page
  final bool isFetchingPreviousPage;

  /// Represents if currently fetching next page
  final bool isFetchingNextPage;

  /// Represents if error occured while fetching previous page
  /// [error] field stores thrown error
  final bool isPreviousPageError;

  /// Represents if error occured while fetching next page
  /// [error] field stores thrown error
  final bool isNextPageError;

  /// Indicates if query has previous page
  final bool hasPreviousPage;

  /// Indicates if query has next page
  final bool hasNextPage;

  @override
  PaginatedRemoterData<T> copyWith({
    String? key,
    Nullable<List<T>>? data,
    Nullable<List<RemoterParam?>>? pageParams,
    Nullable<Object>? error,
    Nullable<DateTime>? updatedAt,
    Nullable<RemoterStatus>? status,
    Nullable<bool>? isRefetching,
    Nullable<bool>? isFetchingPreviousPage,
    Nullable<bool>? isFetchingNextPage,
    Nullable<bool>? isPreviousPageError,
    Nullable<bool>? isNextPageError,
    Nullable<bool>? hasPreviousPage,
    Nullable<bool>? hasNextPage,
    Nullable<int>? failCount,
    Nullable<int>? prevPageFailCount,
    Nullable<int>? nextPageFailCount,
  }) =>
      PaginatedRemoterData<T>(
        key: key ?? this.key,
        data: data == null ? this.data : data.value,
        pageParams: pageParams == null ? this.pageParams : pageParams.value,
        error: error == null ? this.error : error.value,
        updatedAt: updatedAt == null ? this.updatedAt : updatedAt.value,
        status: status == null ? this.status : status.value,
        isRefetching:
            isRefetching == null ? this.isRefetching : isRefetching.value,
        isFetchingNextPage: isFetchingNextPage == null
            ? this.isFetchingNextPage
            : isFetchingNextPage.value,
        isFetchingPreviousPage: isFetchingPreviousPage == null
            ? this.isFetchingPreviousPage
            : isFetchingPreviousPage.value,
        isPreviousPageError: isPreviousPageError == null
            ? this.isPreviousPageError
            : isPreviousPageError.value,
        isNextPageError: isNextPageError == null
            ? this.isNextPageError
            : isNextPageError.value,
        hasPreviousPage: hasPreviousPage == null
            ? this.hasPreviousPage
            : hasPreviousPage.value,
        hasNextPage: hasNextPage == null ? this.hasNextPage : hasNextPage.value,
        failCount: failCount == null ? this.failCount : failCount.value,
        prevPageFailCount: prevPageFailCount == null
            ? this.prevPageFailCount
            : prevPageFailCount.value,
        nextPageFailCount: nextPageFailCount == null
            ? this.nextPageFailCount
            : nextPageFailCount.value,
      );

  /// Creates new copy of [this.data] with mutated element at [index] with [data]
  List<T>? modifyData(int index, T data) {
    if (this.data == null || index > this.data!.length - 1) return null;
    final clone = [...this.data!];
    clone[index] = data;
    return clone;
  }
}

/// {@template paginated_query_functions}
/// Functions are saved on [RemoterClient] when widget mounts
/// [RemoterClient] uses these to fetch following pages
/// `pages` represents all pages in current query
/// Query should have [RemoterStatus.success] status to be able to call these functions
/// {@endtemplate}
class PaginatedQueryFunctions<T> {
  /// {@macro paginated_query_functions}
  PaginatedQueryFunctions({
    this.getPreviousPageParam,
    this.getNextPageParam,
  });

  /// Function is called when previous page fetch is triggered
  /// Returning value will be passed to the `execute` function
  final dynamic Function(List<T> pages)? getPreviousPageParam;

  /// Function is called when next page fetch is triggered
  /// Returning value will be passed to the `execute` function
  final dynamic Function(List<T> pages)? getNextPageParam;
}

/// {@template nullable}
/// Used to distinguish omitted parameter and null
/// {@endtemplate}
class Nullable<T> {
  /// {@macro nullable}
  Nullable(this.value);
  final T? value;
}

/// {@template default}
/// Used to distinguish default parameters and user defined parameters
/// {@endtemplate}
class Default<T> {
  /// {@macro default}
  Default(this.value, {this.isDefault = true});

  /// Stores value of data
  final T value;

  /// If user omits given field and default value is given by constructer
  final bool isDefault;
}

/// {@template remoter_query_utils}
/// Represents class of helper methods which is passed to builder function for [RemoterQuery]
/// These function doesn't add any functionality to [RemoterClient] methods
/// {@endtemplate}
class RemoterQueryUtils<T> {
  /// {@macro remoter_query_utils}
  RemoterQueryUtils({
    required this.invalidateQuery,
    required this.retry,
    required this.setData,
    required this.refetch,
    required this.getData,
  });

  /// Refetches query even if it is not stale
  final FutureOr Function() invalidateQuery;

  /// Retries query if it has status of [RemoterStatus.error]
  final FutureOr Function() retry;

  /// Refetches query only if query is stale
  final FutureOr Function() refetch;

  /// Sets value of query manually
  final FutureOr Function(T data) setData;

  /// Gets current state of query
  final FutureOr<T> Function() getData;
}

/// {@template remoter_paginated_utils}
/// Represents class of helper methods which is passed to builder function for [PaginatedRemoterQuery]
/// These function doesn't add any functionality to [RemoterClient] methods
/// {@endtemplate}
class RemoterPaginatedUtils<T> extends RemoterQueryUtils<T> {
  /// {@macro remoter_paginated_utils}
  RemoterPaginatedUtils({
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required super.getData,
    required super.invalidateQuery,
    required super.retry,
    required super.setData,
    required super.refetch,
  });

  /// Fetches next page if `getNextPageParam` doesn't return null
  final FutureOr Function() fetchNextPage;

  /// Fetches previous page if `getPreviousPageParam` doesn't return null
  final FutureOr Function() fetchPreviousPage;
}

/// {@template remoter_mutation_utils}
/// Represents class for helper methods which is passed to builder function for [RemoterMutation]
/// {@endtemplate}
class RemoterMutationUtils<T, S> {
  /// {@macro remoter_mutation_utils}
  RemoterMutationUtils({
    required this.mutate,
    required this.reset,
    required this.getData,
  });

  /// Function to reset state back to [RemoterStatus.idle] and clear data
  final FutureOr Function() reset;

  /// Calls execute function with given `param`
  final FutureOr Function(S param) mutate;

  /// Get current state object of mutation
  final RemoterMutationData<T> Function() getData;
}

/// {@template remoter_mutation_data}
/// Represents class for mutation object
/// {@endtemplate}
class RemoterMutationData<T> {
  /// {@macro remoter_mutation_data}
  RemoterMutationData({
    required this.data,
    this.status = RemoterStatus.idle,
    this.error,
  });

  /// Represents error object if status is [RemoterStatus.error]
  Object? error;

  /// Represents data given function returns on [RemoterStatus.success]
  T? data;

  /// Represents state of data, default [RemoterStatus.idle]
  RemoterStatus status;

  @override
  String toString() => "RemoterMutationData -> status: $status, data: $data";
}
