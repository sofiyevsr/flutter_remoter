import 'dart:async';

import 'cache.dart';
import 'stream_utils.dart';

class RemoterClient {
  final Map<String, RemoterData> remoterData = {};
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

  // TODO implement fetching from cache
  fetch<T>(String key, Future<T> Function() fn) {
    _dispatch(
      key,
      RemoterData<T>(key: key, data: null, status: RemoterStatus.fetching),
    );
    fn().then((data) {
      _dispatch(
        key,
        RemoterData<T>(key: key, data: data, status: RemoterStatus.isSuccess),
      );
    }).onError((error, stack) {
      _dispatch(
        key,
        RemoterData<T>(
          key: key,
          data: null,
          status: RemoterStatus.isError,
          error: error,
        ),
      );
    });
  }

  void setData<T>(String key, T data) {
    _dispatch(key, RemoterData(key: key, data: data));
  }

  RemoterData<T>? getData<T>(String key) {
    return remoterData[key] as RemoterData<T>?;
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
    /// TODO maybe throw error
    if (listeners[key] == null) return;
    if (listeners[key] == 1) {
      listeners.remove(key);
      _cache.startTimer(key);
    } else {
      listeners[key] = listeners[key]! - 1;
    }
  }

  void _dispatch<T>(String key, RemoterData<T> data) {
    remoterData[key] = data;
    _cacheStream.add(data);
    if (data.data == null) return;
    _cache.setEntry<T>(key, data.data as T);
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
  }) : updatedAt = DateTime.now();
  @override
  String toString() {
    return "RemoteData -> key: $key, value: $data, status: $status, error: $error}";
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
