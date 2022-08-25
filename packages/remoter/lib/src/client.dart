import 'dart:async';

import 'package:clock/clock.dart';
import 'cache.dart';
import 'stream_utils.dart';

/// Client that processes query actions and holds cache data
/// [options] holds global options which is used on each query
class RemoterClient {
  final RemoterClientOptions options;

  ///
  final Map<String, int> listeners = {};
  final RemoterCache _cache;
  final StreamController<RemoterData> _cacheStream =
      StreamController.broadcast();

  RemoterClient({RemoterClientOptions? options})
      : options = options ?? RemoterClientOptions(),
        _cache = RemoterCache();

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
                      status: RemoterStatus.isSuccess,
                    )
                  : null,
            ),
          ),
        );
    return stream;
  }

  Future<void> fetch<T>(String key, Future<T> Function() fn,
      [int? staleTime]) async {
    final initialData = getData<T>(key);

    /// Fetch is in progress already
    if (initialData != null &&
        (initialData.status == RemoterStatus.fetching ||
            initialData.isRefetching == true)) {
      return;
    }

    /// If cache for [key] is there and is not stale
    /// return cache
    if (initialData != null && initialData.status == RemoterStatus.isSuccess) {
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
          status: RemoterStatus.isSuccess,
        ),
      );
    } catch (error) {
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: initialData?.data,
          status: RemoterStatus.isError,
          error: error,
        ),
      );
    }
  }

  void setData<T>(String key, T data) {
    _dispatch(
      key,
      RemoterData<T>(key: key, data: data, status: RemoterStatus.isSuccess),
    );
  }

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
  /// Start timer to delete cache after [cacheTime]
  void decreaseListenersCount(String key, [int? cacheTime]) {
    if (listeners[key] == null) return;
    if (listeners[key] == 1) {
      listeners.remove(key);
      _cache.startTimer(key, cacheTime ?? options.cacheOptions.cacheTime);
    } else {
      listeners[key] = listeners[key]! - 1;
    }
  }

  bool isQueryStale(String key, [int? staleTime]) {
    final entry = _cache.getData<RemoterData>(key);
    if (entry == null) return true;
    final isStale = clock.now().difference(entry.updatedAt).inMilliseconds >=
        (staleTime ?? options.staleTime);
    return isStale;
  }

  void dispose() {
    _cache.close();
  }

  void _dispatch<T>(String key, RemoterData<T> data) {
    _cacheStream.add(data);
    _cache.setEntry<RemoterData<T>>(key, data);
  }
}

class RemoterData<T> {
  String key;
  RemoterStatus status;
  DateTime updatedAt;
  bool isRefetching;
  T? data;
  Object? error;
  RemoterData({
    required this.key,
    required this.data,
    this.error,
    this.isRefetching = false,
    this.status = RemoterStatus.idle,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? clock.now();
  @override
  String toString() {
    return "RemoteData -> key: $key, value: $data, status: $status, error: $error, updatedAt: $updatedAt";
  }
}

class RemoterClientOptions {
  int staleTime;
  CacheOptions cacheOptions;
  RemoterClientOptions({
    this.staleTime = 0,
    int? cacheTime,
  }) : cacheOptions = CacheOptions(cacheTime: cacheTime);
}

enum RemoterStatus {
  idle,
  fetching,
  isSuccess,
  isError,
}
