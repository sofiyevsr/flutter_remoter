import 'package:flutter_remoter/internals/types.dart';
import 'package:flutter_remoter/internals/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      "flatten options doesn't override omitted field and prefers given options over top level options",
      () {
    final topLevelOptions = RemoterOptions(staleTime: 5, cacheTime: 0);
    final options = RemoterOptions(cacheTime: 5);
    final flatOptions = flattenOptions(topLevelOptions, options);
    expect(flatOptions.staleTime.value, 5);
    expect(flatOptions.cacheTime.value, 5);
  });
}
