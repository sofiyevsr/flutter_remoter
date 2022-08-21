const keySeparator = "/-/";

/// Generates string to identify cache based on [key]
String stringifyQueryKey(List<String> key) {
  return key.join(keySeparator);
}
