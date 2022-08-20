import 'dart:async';

import 'package:remoter/src/stream_utils.dart';

/// Cache of all queries
class RemoterCache {
  final Map<String, dynamic> _storage = {};
  final Map<String, Timer> _timers = {};
  final StreamController<CacheEvent> _cacheStream =
      StreamController.broadcast();

  Stream<CacheEvent<T>> getStream<T>(String key) {
    final stream = _cacheStream.stream
        .cast<CacheEvent<T>>()
        .where((event) => event.key == key)
        .transform(
          CustomStreamTransformer<CacheEvent<T>>(
            sink: CustomSink<CacheEvent<T>>(
              _storage[key] != null
                  ? CacheEvent(data: _storage[key], key: key)
                  : null,
            ),
          ),
        );

    return stream;
  }

  /// Set cache in memory and start timer to dispose it
  void setEntry<T>(String key, T data, [CacheOptions? options]) {
    options ??= CacheOptions();
    _storage[key] = data;
    final timer = _setTimer(options.cacheTime, () {
      deleteEntry(key);
      _deleteTimer(key);
    });
    _timers[key] = timer;
    _cacheStream.sink.add(CacheEvent<T>(data: data, key: key));
  }

  /// Delete cache entry with [key]
  /// Shouldn't send null to stream
  void deleteEntry(String key) {
    _storage.remove(key);
  }

  /// Get cache entry with [key]
  T? getData<T>(String key) {
    return _storage[key];
  }

  /// Cancel all timers and streams
  void close() {
    _cacheStream.close();
    _timers.forEach((key, _) {
      _deleteTimer(key);
    });
  }

  /// Cancel [Timer] and deletes from memory
  void _deleteTimer(String key) {
    final timer = _timers[key];
    if (timer?.isActive == true) timer?.cancel();
    _timers.remove(key);
  }

  Timer _setTimer(int duration, Function() onCallback) {
    return Timer(Duration(milliseconds: duration), onCallback);
  }
}

/// Represents object that is pushed when cache is mutated
class CacheEvent<T> {
  String key;
  T data;
  CacheEvent({required this.data, required this.key});

  @override
  String toString() {
    return "key: $key, data: $data";
  }
}

/// Top level options for caching strategy
class CacheOptions {
  int cacheTime;
  CacheOptions({
    this.cacheTime = 5 * 1000 * 60,
  });
}
