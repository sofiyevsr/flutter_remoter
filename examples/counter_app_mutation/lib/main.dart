import 'package:flutter/material.dart';
import 'package:flutter_remoter/flutter_remoter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoterProvider(
      client: RemoterClient(),
      child: const MaterialApp(
        title: 'Flutter Demo',
        home: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoterMutation<int, int>(execute: (param) async {
      await Future.delayed(const Duration(seconds: 1));
      if (param == 4) throw Error();
      return param;
    }, builder: (context, snapshot, utils) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'You have pushed the button this many times:',
              ),
              if (snapshot.status == RemoterStatus.fetching)
                const Text(
                  'loading...',
                ),
              if (snapshot.status == RemoterStatus.error)
                const Text(
                  'error occured because count is 3, see code',
                ),
              Text(
                '${snapshot.data ?? 0}',
                style: Theme.of(context).textTheme.headline4,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: snapshot.status == RemoterStatus.fetching
              ? null
              : () {
                  final current = utils.getData().data ?? 0;
                  utils.mutate(current + 1);
                },
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      );
    });
  }
}
