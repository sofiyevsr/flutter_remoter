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
    final cachedValue = _cache.getData<T>(key);
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
                      data: cachedValue,
                      status: RemoterStatus.isSuccess,
                    )
                  : null,
            ),
          ),
        );
    return stream;
  }

  Future<void> fetch<T>(String key, Future<T> Function() fn) async {
    _fetchFromCache(key);
    try {
      final data = await fn();
      _dispatch(
        key,
        RemoterData<T>(key: key, data: data, status: RemoterStatus.isSuccess),
      );
    } catch (error) {
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: null,
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
    return _cache.getData(key) as RemoterData<T>?;
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

  void _fetchFromCache<T>(String key) {
    final initialData = getData<T>(key);
    // Fetching for first
    if (initialData == null) {
      _dispatch(
        key,
        RemoterData<T>(key: key, data: null, status: RemoterStatus.fetching),
      );
    } else {
      _dispatch(
        key,
        RemoterData<T>(
          key: initialData.key,
          data: initialData.data,
          status: RemoterStatus.fetching,
        ),
      );
    }
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
  T? data;
  Object? error;
  RemoterData({
    required this.key,
    required this.data,
    this.error,
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
