import 'dart:async';

/// Cache of all queries
class RemoterCache {
  final Map<String, dynamic> _storage = {};
  final Map<String, Timer> _timers = {};

  /// Set cache in memory
  void setEntry<T>(
    String key,
    T data,
  ) {
    _storage[key] = data;
  }

  /// Start timer to delete entry with [key]
  /// Used when all listeners are gone
  void startTimer(key, int cacheTime) {
    final timer = _setTimer(cacheTime, () {
      deleteEntry(key);
      deleteTimer(key);
    });
    _timers[key] = timer;
  }

  /// Stop timer to delete entry with [key]
  /// Used when first listener is created
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

  /// Clears all data, all timers and streams
  void close() {
    _storage.clear();
    for (int i = 0; i < _timers.keys.length; i++) {
      deleteTimer(_timers.keys.elementAt(i));
    }
  }

  /// Cancel [Timer] and deletes from memory
  Timer _setTimer(int duration, Function() onCallback) {
    return Timer(Duration(milliseconds: duration), onCallback);
  }
}
