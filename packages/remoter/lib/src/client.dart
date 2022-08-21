import 'dart:async';

import 'cache.dart';
import 'stream_utils.dart';

class RemoterClient {
  final Map<String, int> listeners = {};
  final RemoterClientOptions options;
  final RemoterCache _cache;
  final StreamController<RemoterData> _cacheStream =
      StreamController.broadcast();

  RemoterClient({RemoterClientOptions? options})
      : options = options ?? RemoterClientOptions(),
        _cache = RemoterCache();

  Stream<RemoterData<T>> getStream<T>(String key) {
    final cachedValue = _cache.getData<RemoterData<T>>(key);
    final stream = _cacheStream.stream
        .cast<RemoterData<T>>()
        .where((event) => event.key == key)
        .transform(
          CustomStreamTransformer(
            onClose: () {
              decreaseListenersCount(key);
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

  Future<void> fetch<T>(String key, Future<T> Function() fn) async {
    final dataFromCache = _fetchFromCache<T>(key);
    if (dataFromCache.status == RemoterStatus.fetching) return;
    try {
      final data = await fn();
      // Will behave as refetch if data exists in cache
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
          data: dataFromCache.data,
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

  void increaseListenersCount(String key) {
    if (listeners[key] == null) {
      listeners[key] = 1;
      _cache.deleteTimer(key);
    } else {
      listeners[key] = listeners[key]! + 1;
    }
  }

  void decreaseListenersCount(String key) {
    if (listeners[key] == null) return;
    if (listeners[key] == 1) {
      listeners.remove(key);
      _cache.startTimer(key);
    } else {
      listeners[key] = listeners[key]! - 1;
    }
  }

  /// Returns [hasInitialData] boolean
  RemoterData<T> _fetchFromCache<T>(String key) {
    final initialData = getData<T>(key);
    if (initialData == null) {
      final data = RemoterData<T>(
        key: key,
        data: null,
        status: RemoterStatus.fetching,
      );
      _dispatch(
        key,
        data,
      );
      return data;
    }
    final data = RemoterData<T>(
      key: key,
      data: initialData.data,
      status: RemoterStatus.isSuccess,
      isRefetching: true,
    );
    _dispatch(
      key,
      data,
    );
    return data;
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
  }) : updatedAt = updatedAt ?? DateTime.now();
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
