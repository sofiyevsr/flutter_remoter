import 'dart:async';

import 'package:clock/clock.dart';
import 'types.dart';
import 'cache.dart';
import 'stream_utils.dart';

/// Client that processes query actions and holds cache data
/// [options] holds global options which is used on each query
class RemoterClient {
  final RemoterClientOptions options;

  /// Count of listeners of each key
  final Map<String, int> listeners = {};

  /// Count of listeners of each key
  final Map<String, Future<dynamic> Function()> functions = {};
  final RemoterCache _cache;
  final StreamController<RemoterData> _cacheStream =
      StreamController.broadcast();

  RemoterClient({RemoterClientOptions? options})
      : options = options ?? RemoterClientOptions(),
        _cache = RemoterCache();

  /// Returns new [Stream] which gets cache entry if exists as first data
  Stream<RemoterData<T>> getStream<T>(String key, [int? cacheTime]) {
    final cachedValue = _cache.getData<RemoterData<T>>(key);

    /// Create new stream
    /// that emits latest value from cache first
    final stream = _cacheStream.stream
        .cast<RemoterData<T>>()
        .where((event) => event.key == key)
        .transform(
          CustomStreamTransformer(
            onClose: () {
              decreaseListenersCount(key, cacheTime);
            },
            onListen: () {
              increaseListenersCount(key);
            },
            sink: CustomSink<RemoterData<T>>(
              cachedValue != null
                  ? RemoterData<T>(
                      key: key,
                      data: cachedValue.data,
                      status: RemoterStatus.success,
                    )
                  : null,
            ),
          ),
        );
    return stream;
  }

  /// Executes given function and stores result in cache as entry with [key]
  /// Also this function saves given function to use in invalidateQuery and retry APIs
  Future<void> fetch<T>(String key, Future<T> Function() fn,
      [int? staleTime]) async {
    final initialData = getData<T>(key);
    functions[key] = fn;

    /// Fetch is in progress already
    if (initialData != null &&
        (initialData.status == RemoterStatus.fetching ||
            initialData.isRefetching == true)) {
      return;
    }

    /// If cache for [key] is there and is not stale return cache
    /// If cache is stale, trigger background refetch
    if (initialData != null && initialData.status == RemoterStatus.success) {
      if (isQueryStale(key, staleTime)) {
        _dispatch(
          key,
          RemoterData<T>(
            key: key,
            data: initialData.data,
            status: initialData.status,
            isRefetching: true,
          ),
        );
      } else {
        return _dispatch(key, initialData);
      }
    } else {
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: null,
          status: RemoterStatus.fetching,
        ),
      );
    }
    try {
      final data = await fn();
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: data,
          status: RemoterStatus.success,
        ),
      );
    } catch (error) {
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: initialData?.data,
          status: RemoterStatus.error,
          error: error,
        ),
      );
    }
  }

  /// Triggers a background fetch for given [key] if there is at least 1 listener
  Future<void> invalidateQuery<T>(String key) async {
    final initialData = getData<T>(key);
    final fn = functions[key];
    if (fn == null) return;
    try {
      final data = await fn();
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: data,
          status: RemoterStatus.success,
        ),
      );
    } catch (error) {
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: initialData?.data,
          status: RemoterStatus.error,
          error: error,
        ),
      );
    }
  }

  /// Retries failed query
  /// Query should have [status] of [RemoterStatus.error]
  Future<void> retry<T>(String key) async {
    final initialData = getData<T>(key);
    final fn = functions[key];
    if (fn == null || initialData?.status != RemoterStatus.error) return;
    _dispatch(
      key,
      RemoterData<T>(
        key: key,
        data: null,
        status: RemoterStatus.fetching,
      ),
    );
    try {
      final data = await fn();
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: data,
          status: RemoterStatus.success,
        ),
      );
    } catch (error) {
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: null,
          status: RemoterStatus.error,
          error: error,
        ),
      );
    }
  }

  /// Sets data for entry with [key]
  /// Also notifies listeners with new state
  void setData<T>(String key, T data) {
    _dispatch(
      key,
      RemoterData<T>(key: key, data: data, status: RemoterStatus.success),
    );
  }

  /// Return data from cache
  RemoterData<T>? getData<T>(String key) {
    return _cache.getData<RemoterData<T>>(key);
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
  /// Start timer to delete cache after [cacheTime] or top level [options.staleTime]
  void decreaseListenersCount(String key, [int? cacheTime]) {
    if (listeners[key] == null) return;
    if (listeners[key] == 1) {
      listeners.remove(key);
      _cache.startTimer(key, cacheTime ?? options.cacheTime);
    } else {
      listeners[key] = listeners[key]! - 1;
    }
  }

  /// Return if query is stale based on [staleTime] or top level [options.staleTime]
  bool isQueryStale(String key, [int? staleTime]) {
    final entry = _cache.getData<RemoterData>(key);
    if (entry == null) return true;
    final isStale = clock.now().difference(entry.updatedAt).inMilliseconds >=
        (staleTime ?? options.staleTime);
    return isStale;
  }

  /// Called to release all allocated resources
  void dispose() {
    _cache.close();
  }

  /// Stores data in cache and notifies listeners
  void _dispatch<T>(String key, RemoterData<T> data) {
    _cacheStream.add(data);
    _cache.setEntry<RemoterData<T>>(key, data);
  }
}
