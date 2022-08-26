import 'package:clock/clock.dart';

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
  final int staleTime;
  final int cacheTime;
  RemoterClientOptions({
    this.staleTime = 0,
    this.cacheTime = 5 * 1000 * 60,
  });
}

enum RemoterStatus {
  idle,
  fetching,
  success,
  error,
}
