import 'package:flutter/material.dart';
import 'package:flutter_remoter/internals/client.dart';
import 'package:flutter_remoter/widgets/mutation.dart';
import 'package:flutter_remoter/widgets/provider.dart';
import 'package:flutter_test/flutter_test.dart';

class App extends StatefulWidget {
  final RemoterClient client;
  final Widget child;
  const App({super.key, required this.client, required this.child});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    super.dispose();
    widget.client.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RemoterProvider(
      client: widget.client,
      child: MaterialApp(home: widget.child),
    );
  }
}

void main() {
  testWidgets('updates state accordingly', (tester) async {
    final client = RemoterClient();
    await tester.pumpWidget(App(
      client: client,
      child: RemoterMutation<String, String>(
        execute: (data) =>
            Future.delayed(const Duration(seconds: 1), () => data),
        builder: (ctx, snapshot, utils) {
          return Column(
            children: [
              ElevatedButton(
                key: const Key("mutate"),
                onPressed: () {
                  utils.mutate("data from mutation");
                },
                child: const Text("mutate"),
              ),
              Text(
                snapshot.status.toString(),
                key: const Key("status"),
              ),
              Text(snapshot.data ?? "null"),
            ],
          );
        },
      ),
    ));
    expect(find.text("RemoterStatus.idle"), findsOneWidget);
    await tester.tap(find.byKey(const Key("mutate")));
    await tester.pumpAndSettle();
    expect(find.text("RemoterStatus.fetching"), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text("RemoterStatus.success"), findsOneWidget);
    expect(find.text("data from mutation"), findsOneWidget);
  });

  testWidgets('reset state while fetching data', (tester) async {
    final client = RemoterClient();
    await tester.pumpWidget(App(
      client: client,
      child: RemoterMutation<String, String>(
        execute: (data) =>
            Future.delayed(const Duration(seconds: 1), () => data),
        builder: (ctx, snapshot, utils) {
          return Column(
            children: [
              ElevatedButton(
                key: const Key("mutate"),
                onPressed: () {
                  utils.mutate("data from mutation");
                },
                child: const Text("mutate"),
              ),
              ElevatedButton(
                key: const Key("reset"),
                onPressed: utils.reset,
                child: const Text("reset"),
              ),
              Text(
                snapshot.status.toString(),
                key: const Key("status"),
              ),
            ],
          );
        },
      ),
    ));
    await tester.tap(find.byKey(const Key("mutate")));
    await tester.pumpAndSettle();
    expect(find.text("RemoterStatus.fetching"), findsOneWidget);
    await tester.tap(find.byKey(const Key("reset")));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text("RemoterStatus.idle"), findsOneWidget);
  });
}
