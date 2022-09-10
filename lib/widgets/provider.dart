import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/internals/client.dart';

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
class RemoterProvider extends InheritedWidget {
  final RemoterClient client;
  const RemoterProvider({
    super.key,
    required super.child,
    required this.client,
  });

  static RemoterProvider of(BuildContext context) {
    final RemoterProvider? result =
        context.dependOnInheritedWidgetOfExactType<RemoterProvider>();
    assert(result != null, 'No RemoterProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
