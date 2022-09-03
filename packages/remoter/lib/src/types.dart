import 'package:clock/clock.dart';

/// Both [staleTime] and [cacheTime] should be in milliseconds
class RemoterClientOptions {
  final int staleTime;
  final int cacheTime;
  RemoterClientOptions({
    this.staleTime = 0,
    this.cacheTime = 5 * 1000 * 60,
  });
}

enum RemoterStatus {
  idle,
  fetching,
  success,
  error,
}

enum RemoterParamType {
  previous,
  next,
}

class RemoterParam<T> {
  RemoterParamType type;
  T value;
  RemoterParam({required this.value, required this.type});
}

class BaseRemoterData<T> {
  String key;
  RemoterStatus status;
  DateTime updatedAt;
  bool isRefetching;
  Object? error;
  BaseRemoterData({
    required this.key,
    this.error,
    bool? isRefetching,
    RemoterStatus? status,
    DateTime? updatedAt,
  })  : updatedAt = updatedAt ?? clock.now(),
        isRefetching = isRefetching ?? false,
        status = status ?? RemoterStatus.idle;
  @override
  String toString() {
    return "BaseRemoteData -> key: $key, status: $status, error: $error, updatedAt: $updatedAt";
  }
}

class RemoterData<T> extends BaseRemoterData<T> {
  final T? data;
  RemoterData({
    required super.key,
    required this.data,
    super.updatedAt,
    super.error,
    super.status,
    super.isRefetching,
  });
  RemoterData<T> copyWith({
    String? key,
    Nullable<T>? data,
    Nullable<Object>? error,
    Nullable<DateTime>? updatedAt,
    Nullable<RemoterStatus>? status,
    Nullable<bool>? isRefetching,
  }) =>
      RemoterData<T>(
        key: key ?? this.key,
        data: data == null ? this.data : data.value,
        error: error == null ? this.error : error.value,
        updatedAt: updatedAt == null ? this.updatedAt : updatedAt.value,
        status: status == null ? this.status : status.value,
        isRefetching:
            isRefetching == null ? this.isRefetching : isRefetching.value,
      );
}

class InfiniteRemoterData<T> extends BaseRemoterData<T> {
  final List<RemoterParam?>? pageParams;
  final List<T>? data;
  final bool isFetchingNextPage;
  final bool isFetchingPreviousPage;
  final bool isPreviousPageError;
  final bool isNextPageError;
  final bool hasNextPage;
  final bool hasPreviousPage;
  InfiniteRemoterData({
    required super.key,
    required this.data,
    required this.pageParams,
    super.updatedAt,
    super.error,
    super.status,
    super.isRefetching,
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
        hasNextPage = hasNextPage ?? false;
  InfiniteRemoterData<T> copyWith({
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
  }) =>
      InfiniteRemoterData<T>(
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
      );

  List<T>? modifyData(int index, T data) {
    if (this.data == null || index > this.data!.length - 1) return null;
    final clone = [...this.data!];
    clone[index] = data;
    return clone;
  }
}

/// Represents object that is pushed when cache is mutated
class CacheEvent<T> {
  String key;
  T data;
  CacheEvent({required this.data, required this.key});

  @override
  String toString() {
    return "Cache Event -> key: $key, data: $data";
  }
}

class InfiniteQueryFunctions<T> {
  final dynamic Function(List<T> pages)? getPreviousPageParam;
  final dynamic Function(List<T> pages)? getNextPageParam;
  InfiniteQueryFunctions({
    this.getPreviousPageParam,
    this.getNextPageParam,
  });
}

/// Used to distinguish ommited parameter and null
class Nullable<T> {
  final T? value;
  Nullable(this.value);
}
