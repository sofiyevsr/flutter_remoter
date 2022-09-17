import 'dart:async';

import 'package:clock/clock.dart';
import 'retry.dart';
import 'types.dart';
import 'cache.dart';
import 'utils.dart';

/// Client that processes query actions and holds cache data
/// [options] holds global options which is used on each query
/// see [RemoterOptions] for more details
/// ## IMPORTANT
/// Client methods can be used anywhere in application
/// but generics from methods should not be omitted and should be same as the one used in widgets,
/// otherwise runtime errors will occur
/// For instance, in order to invalidate `RemoterQuery<CatFacts>(remoterkey: "cat_facts")`,
/// `client.invalidateQuery<CatFacts>("cat_facts")` should be called
/// All methods expects either T, RemoterData<T> or PaginatedRemoterData<T>,
/// see method's doc for required generic type
class RemoterClient {
  final RemoterOptions options;

  /// Count of listeners of each key
  final Map<String, int> _listeners = {};

  /// Storage for functions for each key to be used in retry and refetch
  final Map<String, FutureOr Function(RemoterParam? pageParam)> _functions = {};

  /// Function defining parameters to get data for new pages
  final Map<String, PaginatedQueryFunctions> _paginatedQueryFunctions = {};

  /// Storage for all data
  final RemoterCache _cache = RemoterCache();

  /// Stream that sends all entry updates
  final StreamController _cacheStream = StreamController.broadcast();

  /// [options] can be overriden in each query widget
  RemoterClient({RemoterOptions? options})
      : options = options ?? RemoterOptions();

  /// Returns new [Stream] which gets cache entry if exists as first data
  /// [T] expects [RemoterData] or [PaginatedRemoterData] type
  Stream<T> getStream<T extends BaseRemoterData, S>(String key,
      [RemoterOptions? options]) {
    final flatOptions = flattenOptions(this.options, options);
    T? cachedValue = getData<T>(key);
    if (cachedValue == null || cachedValue.status != RemoterStatus.success) {
      cachedValue = null;
    }
    // Create new stream to track listener count
    final stream = _cacheStream.stream
        .cast<T>()
        .where((event) => event.key == key)
        .transform(
          CustomStreamTransformer(
            onClose: () {
              _decreaseListenersCount(key, flatOptions.cacheTime.value);
            },
            onListen: () {
              _increaseListenersCount(key);
            },
          ),
        );
    return stream;
  }

  /// Executes given function and stores result in cache as entry with [key]
  /// Also this function saves given function to use in invalidateQuery and retry APIs
  /// Triggers background refetch if query has run before and is stale now
  /// Retries query if its status is [RemoterStatus.error]
  /// [execute] can only be omitted if this function has been called before with an [execute] function
  /// [T] expects [RemoterData] or [PaginatedRemoterData]
  Future<void> fetch<T extends BaseRemoterData, S>(String key,
      {FutureOr<S> Function(RemoterParam? pageParam)? execute,
      RemoterOptions? options}) async {
    assert(
        T != dynamic &&
            (T == (RemoterData<S>) || T == (PaginatedRemoterData<S>)),
        "[T] should be type of either RemoterData<S> or PaginatedRemoterData<S>");
    assert(execute != null || _functions[key] != null,
        "Couldn't find execute function. Provide an execute function or make sure you have called fetch with an execute function before this call");
    final flatOptions = flattenOptions(this.options, options);
    final initialData = getData<T>(key);
    if (execute == null && _functions[key] == null) {
      return;
    }
    if (execute != null) {
      _functions[key] = execute;
    }

    // Fetch is in progress already
    if (initialData != null &&
        (initialData.status == RemoterStatus.fetching ||
            initialData.isRefetching == true)) {
      return;
    }

    // Retry query if it has error status
    if (initialData?.status == RemoterStatus.error &&
        flatOptions.retryOnMount.value == true) {
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
      if (isQueryStale(key, flatOptions.staleTime.value)) {
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
    if (T == RemoterData<S>) {
      _fetchQuery<S>(
        key,
        flatOptions.maxDelay.value,
        flatOptions.maxRetries.value,
      );
    } else {
      _fetchPaginatedQuery<S>(
        key,
        flatOptions.maxDelay.value,
        flatOptions.maxRetries.value,
      );
    }
  }

  /// Fetches next page of data with [key]
  /// if [PaginatedRemoterData.hasNextPage] of current data is true
  /// [T] expects type of data
  Future<void> fetchNextPage<T>(String key, [RemoterOptions? options]) async {
    final flatOptions = flattenOptions(this.options, options);
    var initialData = getData<PaginatedRemoterData<T>>(key);
    final fn = _functions[key];
    final pageFunctions =
        _paginatedQueryFunctions[key] as PaginatedQueryFunctions<T>?;
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
        maxDelay: flatOptions.maxDelay.value,
        maxRetries: flatOptions.maxRetries.value,
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
          hasPreviousPage: Nullable(
              pageFunctions.getPreviousPageParam?.call(mergedData) != null),
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
  /// [T] expects type of data
  Future<void> fetchPreviousPage<T>(String key,
      [RemoterOptions? options]) async {
    final flatOptions = flattenOptions(this.options, options);
    var initialData = getData<PaginatedRemoterData<T>>(key);
    final fn = _functions[key];
    final pageFunctions =
        _paginatedQueryFunctions[key] as PaginatedQueryFunctions<T>?;
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
        maxDelay: flatOptions.maxDelay.value,
        maxRetries: flatOptions.maxRetries.value,
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
          hasNextPage: Nullable(
              pageFunctions.getNextPageParam?.call(mergedData) != null),
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
  /// [T] expects type of data
  Future<void> invalidateQuery<T>(String key, [RemoterOptions? options]) async {
    final flatOptions = flattenOptions(this.options, options);
    final initialData = getData<BaseRemoterData<T>>(key);
    final fn = _functions[key];
    if (fn == null || _listeners[key] == null || _listeners[key]! < 1) return;
    if (initialData is RemoterData) {
      _dispatch(
        key,
        (initialData as RemoterData).copyWith(isRefetching: Nullable(true)),
      );
      _fetchQuery<T>(
        key,
        flatOptions.maxDelay.value,
        flatOptions.maxRetries.value,
      );
    } else if (initialData is PaginatedRemoterData) {
      _dispatch(
        key,
        (initialData as PaginatedRemoterData).copyWith(
          isRefetching: Nullable(true),
        ),
      );
      _fetchPaginatedQuery<T>(
        key,
        flatOptions.maxDelay.value,
        flatOptions.maxRetries.value,
      );
    }
  }

  /// Retries failed query
  /// Query should have status of [RemoterStatus.error]
  /// [T] expects type of data
  Future<void> retry<T>(String key, [RemoterOptions? options]) async {
    final flatOptions = flattenOptions(this.options, options);
    final initialData = getData<BaseRemoterData<T>>(key);
    final fn = _functions[key];
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
      _fetchQuery<T>(
        key,
        flatOptions.maxDelay.value,
        flatOptions.maxRetries.value,
      );
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
      _fetchPaginatedQuery<T>(
        key,
        flatOptions.maxDelay.value,
        flatOptions.maxRetries.value,
      );
    }
  }

  /// Stores functions for paginated queries of how to fetch new pages
  void savePaginatedQueryFunctions(
    String key,
    PaginatedQueryFunctions functions,
  ) {
    _paginatedQueryFunctions[key] = functions;
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

  /// Return if query is stale based on [staleTime]
  bool isQueryStale(String key, int staleTime) {
    final entry = getData<BaseRemoterData>(key);
    if (entry == null) return true;
    final isStale =
        clock.now().difference(entry.updatedAt).inMilliseconds >= staleTime;
    return isStale;
  }

  /// Called to release all allocated resources
  void dispose() {
    _listeners.clear();
    _functions.clear();
    _paginatedQueryFunctions.clear();
    _cacheStream.close();
    _cache.close();
  }

  /// Gets count of current listeners for given [key]
  int? getListenersCount(String key) {
    return _listeners[key];
  }

  /// Increases listeners count for [key]
  /// If key was scheduled for being deleted (no listener is there),
  /// then stop timer that deletes cache
  void _increaseListenersCount(String key) {
    if (_listeners[key] == null) {
      _listeners[key] = 1;
      _cache.deleteTimer(key);
    } else {
      _listeners[key] = _listeners[key]! + 1;
    }
  }

  /// Decrease listeners count for [key]
  /// If there is no listener
  /// Start timer to delete cache after [cacheTime]
  void _decreaseListenersCount(String key, int cacheTime) {
    if (_listeners[key] == null) return;
    if (_listeners[key] == 1) {
      _listeners.remove(key);
      _cache.startTimer(key, cacheTime);
    } else {
      _listeners[key] = _listeners[key]! - 1;
    }
  }

  /// [T] expects type of data
  Future<void> _fetchQuery<T>(
    String key,
    int maxDelay,
    int maxRetries,
  ) async {
    final fn = _functions[key];
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

  /// [T] expects type of data
  Future<void> _fetchPaginatedQuery<T>(
    String key,
    int maxDelay,
    int maxRetries,
  ) async {
    final fn = _functions[key];
    final pagefn = _paginatedQueryFunctions[key] as PaginatedQueryFunctions<T>?;
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
                  error: Nullable(null),
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
