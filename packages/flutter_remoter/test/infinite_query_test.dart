import 'package:flutter/material.dart';
import 'package:flutter_remoter/src/infinite_remoter_query.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_remoter/flutter_remoter.dart';
import 'package:remoter/remoter.dart';

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
  testWidgets('renders initial data on startup', (tester) async {
    final client = RemoterClient();
    client.saveInfiniteQueryFunctions(
      "cache",
      InfiniteQueryFunctions(getNextPageParam: (pages) => "next"),
    );
    await client.fetchInfinite<String>("cache", (_) async => "result");
    await tester.pumpWidget(App(
      client: client,
      child: RemoterInfiniteQuery<String>(
        remoterKey: "cache",
        execute: (_) async {
          return "data from execute";
        },
        builder: (ctx, snapshot, utils) => Text(snapshot.data?[0] ?? "null"),
      ),
    ));
    expect(find.text("result"), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text("data from execute"), findsOneWidget);
  });
}
