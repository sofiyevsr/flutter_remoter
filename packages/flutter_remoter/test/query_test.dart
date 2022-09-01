import 'package:flutter/material.dart';
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
    await client.fetch<String>("cache", (_) async => "result");
    await tester.pumpWidget(App(
      client: client,
      child: RemoterQuery<String>(
        remoterKey: "cache",
        execute: () async {
          return "data from execute";
        },
        builder: (ctx, snapshot) => Text(snapshot.data ?? "null"),
      ),
    ));
    expect(find.text("result"), findsOneWidget);
  });

  testWidgets("refetches when new listener mounted", (tester) async {
    final client = RemoterClient(
      options: RemoterClientOptions(staleTime: 0),
    );
    await client.fetch<String>("cache", (_) async => "result");
    await tester.pumpWidget(App(
      client: client,
      child: RemoterQuery<String>(
        remoterKey: "cache",
        execute: () async {
          return "data from execute";
        },
        builder: (ctx, snapshot) => Text(snapshot.data ?? "null"),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text("data from execute"), findsOneWidget);
  });

  testWidgets('renders update', (tester) async {
    final client = RemoterClient();
    await tester.pumpWidget(App(
      client: client,
      child: RemoterQuery<String>(
        remoterKey: "cache",
        execute: () async {
          return "data from execute";
        },
        builder: (ctx, snapshot) => Text(snapshot.data ?? "null"),
      ),
    ));
    expect(find.text("null"), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text("data from execute"), findsOneWidget);
  });

  testWidgets('handles status correctly', (tester) async {
    final client = RemoterClient();
    await tester.pumpWidget(App(
      client: client,
      child: RemoterQuery<String>(
        remoterKey: "cache",
        execute: () async {
          return "data from execute";
        },
        builder: (ctx, snapshot) => Text(snapshot.status.name),
      ),
    ));
    expect(find.text("fetching"), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text("success"), findsOneWidget);
  });

  testWidgets('invalidate query', (tester) async {
    final client = RemoterClient();
    int count = 0;
    await tester.pumpWidget(App(
      client: client,
      child: RemoterQuery<int>(
        remoterKey: "cache",
        execute: () async {
          return count++;
        },
        builder: (ctx, snapshot) => Text(snapshot.data?.toString() ?? "null"),
      ),
    ));
    expect(find.text("null"), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text("0"), findsOneWidget);
    await client.invalidateQuery<int>("cache");
    await tester.pumpAndSettle();
    expect(find.text("1"), findsOneWidget);
  });
}