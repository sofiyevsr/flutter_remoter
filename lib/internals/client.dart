import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_remoter/internals/retry.dart';
import 'types.dart';
import 'cache.dart';
import 'stream_utils.dart';

/// Function type for query's fetch function
typedef FetchFunction<T> = FutureOr<T> Function(RemoterParam? pageParam);

/// Client that processes query actions and holds cache data
/// [options] holds global options which is used on each query
class RemoterClient {
  final RemoterClientOptions options;

  /// Count of listeners of each key
  final Map<String, int> listeners = {};

  /// Storage for functions for each key to be used in retry and refetch
  final Map<String, FetchFunction> functions = {};

  /// Function defining parameters to get data for new pages
  final Map<String, PaginatedQueryFunctions> paginatedQueryFunctions = {};

  /// Storage for all data
  final RemoterCache _cache = RemoterCache();

  /// Stream that sends all entry updates
  final StreamController _cacheStream = StreamController.broadcast();

  /// [options] can be overriden in each query widget
  RemoterClient({RemoterClientOptions? options})
      : options = options ?? RemoterClientOptions();

  /// Returns new [Stream] which gets cache entry if exists as first data
  /// [T] expects [RemoterData] or [PaginatedRemoterData] type
  Stream<T> getStream<T extends BaseRemoterData, S>(String key,
      [int? cacheTime]) {
    T? cachedValue = getData<T>(key);
    if (cachedValue == null || cachedValue.status != RemoterStatus.success) {
      cachedValue = null;
    }

    // Create new stream
    // that emits latest value from cache first
    final stream = _cacheStream.stream
        .cast<T>()
        .where((event) => event.key == key)
        .transform(
          CustomStreamTransformer(
            onClose: () {
              decreaseListenersCount(key, cacheTime);
            },
            onListen: () {
              increaseListenersCount(key);
            },
            sink: CustomSink<T>(cachedValue),
          ),
        );
    return stream;
  }

  /// Executes given function and stores result in cache as entry with [key]
  /// Also this function saves given function to use in invalidateQuery and retry APIs
  /// Can also be used as refetch function
  /// Retries query if its status is [RemoterStatus.error]
  /// [T] expects any data type
  Future<void> fetch<T>(
    String key,
    FetchFunction fn, {
    int? staleTime,
    int? maxDelay,
    int? maxRetries,
    bool? retryOnMount,
  }) async {
    maxDelay = maxDelay ?? options.maxDelay;
    maxRetries = maxRetries ?? options.maxRetries;
    retryOnMount = retryOnMount ?? options.retryOnMount;
    final initialData = getData<RemoterData<T>>(key);
    functions[key] = fn;

    // Fetch is in progress already
    if (initialData != null &&
        (initialData.status == RemoterStatus.fetching ||
            initialData.isRefetching == true)) {
      return;
    }

    // Retry query if it has error status
    if (initialData?.status == RemoterStatus.error && retryOnMount == true) {
      _dispatch(
        key,
        initialData!.copyWith(
          error: Nullable(null),
          status: Nullable(RemoterStatus.fetching),
        ),
      );
    }

    // If cache for [key] is there and is not stale return cache
    // If cache is stale, trigger background refetch
    if (initialData?.status == RemoterStatus.success) {
      if (isQueryStale(key, staleTime)) {
        _dispatch(
          key,
          initialData!.copyWith(
            isRefetching: Nullable(true),
          ),
        );
      } else {
        return _dispatch(key, initialData);
      }
    }
    _fetchQuery<T>(key, maxDelay, maxRetries);
  }

  /// Executes given function and stores result in cache as entry with [key]
  /// Also this function saves given function to use in invalidateQuery and retry APIs
  /// Can also be used as refetch function
  /// Retries query if its status is [RemoterStatus.error]
  /// [T] expects any data type
  Future<void> fetchPaginated<T>(
    String key,
    FetchFunction fn, {
    int? staleTime,
    int? maxDelay,
    int? maxRetries,
    bool? retryOnMount,
  }) async {
    maxDelay = maxDelay ?? options.maxDelay;
    maxRetries = maxRetries ?? options.maxRetries;
    retryOnMount = retryOnMount ?? options.retryOnMount;
    final initialData = getData<PaginatedRemoterData<T>>(key);
    functions[key] = fn;

    // Fetch is in progress already
    if (initialData != null &&
        (initialData.status == RemoterStatus.fetching ||
            initialData.isRefetching == true)) {
      return;
    }

    // Retry query if it has error status
    if (initialData?.status == RemoterStatus.error && retryOnMount == true) {
      _dispatch(
        key,
        initialData!.copyWith(
          error: Nullable(null),
          status: Nullable(RemoterStatus.fetching),
        ),
      );
    }

    // If cache for [key] is there and is not stale return cache
    // If cache is stale, trigger background refetch
    if (initialData?.status == RemoterStatus.success) {
      if (isQueryStale(key, staleTime)) {
        _dispatch(
          key,
          initialData!.copyWith(isRefetching: Nullable(true)),
        );
      } else {
        return _dispatch(key, initialData);
      }
    }
    _fetchPaginatedQuery<T>(key, maxDelay, maxRetries);
  }

  /// Fetches next page of data with [key]
  /// if [PaginatedRemoterData.hasNextPage] of current data is true
  /// [T] expects any data type
  Future<void> fetchNextPage<T>(String key,
      [int? maxDelay, int? maxRetries]) async {
    maxDelay = maxDelay ?? options.maxDelay;
    maxRetries = maxRetries ?? options.maxRetries;
    var initialData = getData<PaginatedRemoterData<T>>(key);
    final fn = functions[key];
    final pageFunctions =
        paginatedQueryFunctions[key] as PaginatedQueryFunctions<T>?;
    if (fn == null ||
        pageFunctions?.getNextPageParam == null ||
        initialData?.isFetchingNextPage == true ||
        initialData?.hasNextPage == false ||
        initialData?.data == null ||
        initialData?.status != RemoterStatus.success) {
      return;
    }
    final pageParam = pageFunctions!.getNextPageParam!(initialData!.data!);
    try {
      _dispatch(
        key,
        initialData.copyWith(isFetchingNextPage: Nullable(true)),
      );
      final param = RemoterParam(value: pageParam, type: RemoterParamType.next);
      final data = await retryFuture(
        () => fn(param),
        onFail: (attempts) {
          final initialData = getData<PaginatedRemoterData<T>>(key);
          _dispatch(
            key,
            initialData?.copyWith(
              nextPageFailCount: Nullable(attempts),
            ),
          );
          return false;
        },
        maxDelay: maxDelay,
        maxRetries: maxRetries,
      );

      // Update data after function runs
      initialData = getData<PaginatedRemoterData<T>>(key);
      if (initialData?.hasNextPage == false ||
          initialData?.data == null ||
          initialData?.status != RemoterStatus.success) {
        return;
      }
      final mergedData = [...initialData!.data!, data as T];
      _dispatch(
        key,
        initialData.copyWith(
          key: key,
          pageParams: Nullable([
            ...(initialData.pageParams ?? [null]),
            param,
          ]),
          data: Nullable(mergedData),
          hasNextPage: Nullable(
              pageFunctions.getNextPageParam?.call(mergedData) != null),
          isFetchingNextPage: Nullable(false),
          nextPageFailCount: Nullable(0),
        ),
      );
    } catch (error) {
      // Update data because fetch function can mutate failCount
      initialData = getData<PaginatedRemoterData<T>>(key);
      _dispatch(
        key,
        initialData?.copyWith(
          isFetchingNextPage: Nullable(false),
          isNextPageError: Nullable(true),
          error: Nullable(error),
        ),
      );
    }
  }

  /// Fetches previous page of data with [key]
  /// if [PaginatedRemoterData.hasPreviousPage] of current data is true
  /// [T] expects any data type
  Future<void> fetchPreviousPage<T>(String key,
      [int? maxDelay, int? maxRetries]) async {
    maxDelay = maxDelay ?? options.maxDelay;
    maxRetries = maxRetries ?? options.maxRetries;
    var initialData = getData<PaginatedRemoterData<T>>(key);
    final fn = functions[key];
    final pageFunctions =
        paginatedQueryFunctions[key] as PaginatedQueryFunctions<T>?;
    if (fn == null ||
        pageFunctions?.getPreviousPageParam == null ||
        initialData?.isFetchingPreviousPage == true ||
        initialData?.hasPreviousPage == false ||
        initialData?.data == null ||
        initialData?.status != RemoterStatus.success) {
      return;
    }
    final pageParam = pageFunctions!.getPreviousPageParam!(initialData!.data!);
    try {
      _dispatch(
        key,
        initialData.copyWith(isFetchingPreviousPage: Nullable(true)),
      );
      final param =
          RemoterParam(value: pageParam, type: RemoterParamType.previous);
      final data = await retryFuture(
        () => fn(param),
        onFail: (attempts) {
          final initialData = getData<PaginatedRemoterData<T>>(key);
          _dispatch(
            key,
            initialData?.copyWith(
              prevPageFailCount: Nullable(attempts),
            ),
          );
          return false;
        },
        maxDelay: maxDelay,
        maxRetries: maxRetries,
      );
      // Update data after function runs
      initialData = getData<PaginatedRemoterData<T>>(key);
      if (initialData?.hasPreviousPage == false ||
          initialData?.data == null ||
          initialData?.status != RemoterStatus.success) {
        return;
      }
      final mergedData = [data as T, ...initialData!.data!];
      _dispatch(
        key,
        initialData.copyWith(
          key: key,
          pageParams: Nullable([
            param,
            ...(initialData.pageParams ?? [null])
          ]),
          data: Nullable(mergedData),
          hasPreviousPage: Nullable(
              pageFunctions.getPreviousPageParam?.call(mergedData) != null),
          isFetchingPreviousPage: Nullable(false),
          prevPageFailCount: Nullable(0),
        ),
      );
    } catch (error) {
      // Update data because fetch function can mutate failCount
      initialData = getData<PaginatedRemoterData<T>>(key);
      _dispatch(
        key,
        initialData?.copyWith(
          isFetchingPreviousPage: Nullable(false),
          isPreviousPageError: Nullable(true),
          error: Nullable(error),
        ),
      );
    }
  }

  /// Triggers a background fetch for given [key] if there is at least 1 listener
  /// Ignores staleTime
  /// [T] expects any data type
  Future<void> invalidateQuery<T>(String key,
      [int? maxDelay, int? maxRetries]) async {
    maxDelay = maxDelay ?? options.maxDelay;
    maxRetries = maxRetries ?? options.maxRetries;
    final initialData = getData<BaseRemoterData<T>>(key);
    final fn = functions[key];
    if (fn == null || listeners[key] == null || listeners[key]! < 1) return;
    if (initialData is RemoterData) {
      _dispatch(
        key,
        (initialData as RemoterData).copyWith(isRefetching: Nullable(true)),
      );
      _fetchQuery<T>(key, maxDelay, maxRetries);
    } else if (initialData is PaginatedRemoterData) {
      _dispatch(
        key,
        (initialData as PaginatedRemoterData)
            .copyWith(isRefetching: Nullable(true)),
      );
      _fetchPaginatedQuery<T>(key, maxDelay, maxRetries);
    }
  }

  /// Retries failed query
  /// Query should have status of [RemoterStatus.error]
  /// [T] expects any data type
  Future<void> retry<T>(String key, [int? maxDelay, int? maxRetries]) async {
    maxDelay = maxDelay ?? options.maxDelay;
    maxRetries = maxRetries ?? options.maxRetries;
    final initialData = getData<BaseRemoterData<T>>(key);
    final fn = functions[key];
    if (fn == null || initialData?.status != RemoterStatus.error) return;
    if (initialData is RemoterData) {
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: null,
          status: RemoterStatus.fetching,
        ),
      );
      _fetchQuery<T>(key, maxDelay, maxRetries);
    } else {
      _dispatch(
        key,
        PaginatedRemoterData<T>(
          key: key,
          data: null,
          pageParams: null,
          status: RemoterStatus.fetching,
        ),
      );
      _fetchPaginatedQuery<T>(key, maxDelay, maxRetries);
    }
  }

  /// Stores functions for paginated queries of how to fetch new pages
  void savePaginatedQueryFunctions(
    String key,
    PaginatedQueryFunctions functions,
  ) {
    paginatedQueryFunctions[key] = functions;
  }

  /// Sets data for entry with [key]
  /// Also notifies listeners with new state
  /// [T] expects [RemoterData] or [PaginatedRemoterData] type
  void setData<T extends BaseRemoterData>(String key, T data) {
    _dispatch(
      key,
      data,
    );
  }

  /// Return data from cache
  /// [T] expects [RemoterData] or [PaginatedRemoterData] type
  T? getData<T>(String key) {
    return _cache.getData<T>(key);
  }

  /// Increases listeners count for [key]
  /// If key was scheduled for being deleted (no listener is there),
  /// then stop timer that deletes cache
  void increaseListenersCount(String key) {
    if (listeners[key] == null) {
      listeners[key] = 1;
      _cache.deleteTimer(key);
    } else {
      listeners[key] = listeners[key]! + 1;
    }
  }

  /// Decrease listeners count for [key]
  /// If there is no listener
  /// Start timer to delete cache after [cacheTime]
  void decreaseListenersCount(String key, [int? cacheTime]) {
    if (listeners[key] == null) return;
    if (listeners[key] == 1) {
      listeners.remove(key);
      _cache.startTimer(key, cacheTime ?? options.cacheTime);
    } else {
      listeners[key] = listeners[key]! - 1;
    }
  }

  /// Return if query is stale based on [staleTime]
  bool isQueryStale(String key, [int? staleTime]) {
    final entry = getData<BaseRemoterData>(key);
    if (entry == null) return true;
    final isStale = clock.now().difference(entry.updatedAt).inMilliseconds >=
        (staleTime ?? options.staleTime);
    return isStale;
  }

  /// Called to release all allocated resources
  void dispose() {
    listeners.clear();
    functions.clear();
    paginatedQueryFunctions.clear();
    _cacheStream.close();
    _cache.close();
  }

  /// [T] expects any data type
  Future<void> _fetchQuery<T>(
    String key,
    int maxDelay,
    int maxRetries,
  ) async {
    final fn = functions[key];
    if (fn == null) return;
    int failCount = 0;
    var initialData = getData<RemoterData<T>>(key);
    try {
      final data = await retryFuture(
        () => fn(null),
        onFail: (attempts) {
          failCount = attempts;
          final initialData = getData<RemoterData<T>>(key);
          _dispatch(
            key,
            initialData?.copyWith(
                  failCount: Nullable(attempts),
                ) ??
                RemoterData<T>(
                  key: key,
                  data: null,
                  status: RemoterStatus.fetching,
                  failCount: attempts,
                ),
          );
          return false;
        },
        maxDelay: maxDelay,
        maxRetries: maxRetries,
      );
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: data,
          status: RemoterStatus.success,
        ),
      );
    } catch (error) {
      // Update data because fetch function can mutate failCount
      initialData = getData<RemoterData<T>>(key);
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: initialData?.data,
          status: RemoterStatus.error,
          error: error,
          failCount: failCount,
        ),
      );
    }
  }

  /// [T] expects any data type
  Future<void> _fetchPaginatedQuery<T>(
    String key,
    int maxDelay,
    int maxRetries,
  ) async {
    final fn = functions[key];
    final pagefn = paginatedQueryFunctions[key] as PaginatedQueryFunctions<T>?;
    if (fn == null) return;
    var initialData = getData<PaginatedRemoterData<T>>(key);
    final pageParams = initialData?.pageParams ?? [null];
    final List<Future<void>> futures = [];
    for (int i = 0; i < pageParams.length; i++) {
      futures.add(() async {
        int failCount = 0;
        try {
          final data = await retryFuture(
            () => fn(pageParams[i]),
            onFail: (attempts) {
              failCount = attempts;
              final initialData = getData<PaginatedRemoterData<T>>(key);
              _dispatch(
                key,
                initialData?.copyWith(
                      failCount: Nullable(attempts),
                    ) ??
                    PaginatedRemoterData<T>(
                      key: key,
                      data: null,
                      pageParams: null,
                      status: RemoterStatus.fetching,
                      failCount: attempts,
                    ),
              );
              return false;
            },
            maxDelay: maxDelay,
            maxRetries: maxRetries,
          );
          // This is required to getLatest data to avoid overriding state
          // on concurrent actions
          initialData = getData<PaginatedRemoterData<T>>(key);
          final modifiedData = initialData?.modifyData(i, data) ?? [data as T];
          _dispatch(
            key,
            initialData?.copyWith(
                  status: Nullable(RemoterStatus.success),
                  data: Nullable(modifiedData),
                  hasNextPage: Nullable(
                    pagefn?.getNextPageParam?.call(modifiedData) != null,
                  ),
                  hasPreviousPage: Nullable(
                    pagefn?.getPreviousPageParam?.call(modifiedData) != null,
                  ),
                  updatedAt: Nullable(clock.now()),
                  failCount: Nullable(0),
                  isRefetching: Nullable(false),
                ) ??
                PaginatedRemoterData<T>(
                  key: key,
                  pageParams: pageParams,
                  data: [data],
                  hasNextPage: pagefn?.getNextPageParam?.call([data]) != null,
                  hasPreviousPage:
                      pagefn?.getPreviousPageParam?.call([data]) != null,
                  status: RemoterStatus.success,
                ),
          );
        } catch (error) {
          // Update data because fetch function can mutate failCount
          initialData = getData<PaginatedRemoterData<T>>(key);
          if (initialData?.data == null) {
            _dispatch(
              key,
              PaginatedRemoterData<T>(
                key: key,
                pageParams: null,
                data: null,
                status: RemoterStatus.error,
                error: error,
                failCount: failCount,
              ),
            );
          }
        }
      }());
    }
    await Future.wait(futures);
  }

  /// Stores data in cache and notifies listeners
  /// [T] expects [RemoterData] or [PaginatedRemoterData] type
  void _dispatch<T>(String key, T data) {
    _cacheStream.add(data);
    _cache.setEntry<T>(key, data);
  }
}
