import 'dart:async';

import 'package:clock/clock.dart';

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
class RemoterOptions {
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

/// Represents parameter object passed to [PaginatedRemoterQuery.execute]
class RemoterParam<T> {
  RemoterParamType type;
  T value;
  RemoterParam({required this.value, required this.type});
}

/// Represents abstraction for [RemoterData] and [PaginatedRemoterData]
abstract class BaseRemoterData<T> {
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

/// Represents data fetched for [RemoterQuery]
/// [T] represents the type of data fetched in the query
class RemoterData<T> extends BaseRemoterData<T> {
  /// Represents data execute function returns on [RemoterStatus.success]
  final T? data;

  RemoterData({
    required super.key,
    required this.data,
    super.updatedAt,
    super.error,
    super.status,
    super.isRefetching,
    super.failCount,
  });
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

/// Represents data fetched for [PaginatedRemoterQuery]
/// [T] represents the type of data in list of pages fetched in the query
class PaginatedRemoterData<T> extends BaseRemoterData<T> {
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

/// Functions are saved on [RemoterClient] when widget mounts
/// [RemoterClient] uses these to fetch following pages
/// `pages` represents all pages in current query
/// Query should have [RemoterStatus.success] status to be able to call these functions
class PaginatedQueryFunctions<T> {
  final dynamic Function(List<T> pages)? getPreviousPageParam;
  final dynamic Function(List<T> pages)? getNextPageParam;
  PaginatedQueryFunctions({
    this.getPreviousPageParam,
    this.getNextPageParam,
  });
}

/// Used to distinguish omitted parameter and null
class Nullable<T> {
  final T? value;
  Nullable(this.value);
}

/// Used to distinguish default parameters and user defined parameters
class Default<T> {
  /// Stores value of data
  final T value;

  /// If user omits given field and default value is given by constructer
  final bool isDefault;
  Default(this.value, {this.isDefault = true});
}

/// Represents class of helper methods which is passed to builder function for [RemoterQuery]
/// These function doesn't add any functionality to [RemoterClient] methods
class RemoterQueryUtils<T> {
  final FutureOr Function() invalidateQuery;
  final FutureOr Function() retry;
  final FutureOr Function() refetch;
  final FutureOr Function(T data) setData;
  final FutureOr<T> Function() getData;
  RemoterQueryUtils({
    required this.invalidateQuery,
    required this.retry,
    required this.setData,
    required this.refetch,
    required this.getData,
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
    required super.getData,
    required super.invalidateQuery,
    required super.retry,
    required super.setData,
    required super.refetch,
  });
}

/// Represents class for helper methods which is passed to builder function for [RemoterMutation]
class RemoterMutationUtils<T, S> {
  final FutureOr Function() reset;
  final FutureOr Function(S param) mutate;
  final RemoterMutationData<T> Function() getData;
  RemoterMutationUtils({
    required this.mutate,
    required this.reset,
    required this.getData,
  });
}

/// Represents class for mutation object
class RemoterMutationData<T> {
  /// Represents error object if status is [RemoterStatus.error]
  Object? error;

  /// Represents data given function returns on [RemoterStatus.success]
  T? data;

  /// Represents state of data, default [RemoterStatus.idle]
  RemoterStatus status;
  RemoterMutationData({
    required this.data,
    this.status = RemoterStatus.idle,
    this.error,
  });
  @override
  String toString() => "RemoterMutationData -> status: $status, data: $data";
}
