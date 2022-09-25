import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/src/internals/client.dart';

/// {@template remoter_provider}
/// Creates provider with [RemoterClient]
/// so that a single instance of [RemoterClient] can be accessed from children
///
/// ```dart
///    RemoterProvider(
///      client: RemoterClient(),
///      child: const MaterialApp(
///        home: MyHomePage(),
///      ),
///    );
/// ```
/// {@endtemplate}
class RemoterProvider extends InheritedWidget {
  /// {@macro remoter_provider}
  const RemoterProvider({
    super.key,
    required super.child,
    required this.client,
  });

  /// Client instance that will be used by all child widgets
  final RemoterClient client;

  static RemoterProvider of(BuildContext context) {
    final RemoterProvider? result =
        context.dependOnInheritedWidgetOfExactType<RemoterProvider>();
    assert(result != null, 'No RemoterProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
