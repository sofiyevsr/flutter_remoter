import 'dart:async';

/// Cache of all queries
class RemoterCache {
  final Map<String, dynamic> _storage = {};
  final Map<String, Timer> _timers = {};

  /// Set cache in memory and start timer to dispose it
  void setEntry<T>(
    String key,
    T data,
  ) {
    _storage[key] = data;
  }

  /// Start timer to delete entry with [key]
  /// When all listeners are gone
  void startTimer(key, [CacheOptions? options]) {
    options ??= CacheOptions();
    final timer = _setTimer(options.cacheTime, () {
      deleteEntry(key);
      deleteTimer(key);
    });
    _timers[key] = timer;
  }

  /// Stop timer to delete entry with [key]
  /// When new listener is created
  void deleteTimer(String key) {
    final timer = _timers[key];
    if (timer == null) return;
    if (timer.isActive == true) timer.cancel();
    _timers.remove(key);
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
    _timers.forEach((key, _) {
      deleteTimer(key);
    });
  }

  /// Cancel [Timer] and deletes from memory

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
    return "Cache Event -> key: $key, data: $data";
  }
}

/// Top level options for caching strategy
class CacheOptions {
  int cacheTime;
  CacheOptions({int? cacheTime}) : cacheTime = cacheTime ?? 5 * 1000 * 60;

  @override
  String toString() {
    return "Cache Options -> cacheTime: $cacheTime";
  }
}
