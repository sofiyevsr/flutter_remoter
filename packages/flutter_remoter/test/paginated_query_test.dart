import 'dart:async';

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
    await client.fetchPaginated<String>("cache", (_) async => "result");
    await tester.pumpWidget(App(
      client: client,
      child: PaginatedRemoterQuery<String>(
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

  testWidgets('listener is called with old and new state', (tester) async {
    final client = RemoterClient();
    final controller = StreamController<List<String?>>();
    await tester.pumpWidget(App(
      client: client,
      child: PaginatedRemoterQuery<String>(
        remoterKey: "cache",
        listener: (o, n) {
          controller.add([o.data?[0], n.data?[0]]);
          controller.close();
        },
        execute: (_) {
          return "result";
        },
        builder: (ctx, snapshot, _) =>
            Text(snapshot.data?.toString() ?? "null"),
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      controller.stream,
      emitsInOrder([
        [null, "result"],
        emitsDone
      ]),
    );
  });

  testWidgets('query won\'t start unless disable is false', (tester) async {
    final client = RemoterClient();
    final streamController = StreamController<bool>();
    await tester.pumpWidget(App(
      client: client,
      child: StreamBuilder<bool>(
          initialData: true,
          stream: streamController.stream,
          builder: (context, snapshot) {
            return PaginatedRemoterQuery<String>(
              remoterKey: "cache",
              disabled: snapshot.data,
              execute: (_) async {
                return "data from execute";
              },
              builder: (ctx, snapshot, utils) {
                if (snapshot.status == RemoterStatus.idle) {
                  return const Text("idle");
                }
                return Text(snapshot.data?[0] ?? "null");
              },
            );
          }),
    ));
    expect(find.text("idle"), findsOneWidget);
    streamController.sink.add(false);
    await tester.pumpAndSettle();
    expect(find.text("data from execute"), findsOneWidget);
  });
}
