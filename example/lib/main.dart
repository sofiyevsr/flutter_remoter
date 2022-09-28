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
      client: RemoterClient(
        options: RemoterOptions(
            // Infinite staleTime means it won't be refetched on startup
            // 1 << 31 is max int32
            // staleTime: 1 << 31,
            // 0 cacheTime means query will be cleared after 0 ms after all listeners gone
            // cacheTime: 0,
            ),
      ),
      child: const MaterialApp(
        title: 'Remoter Demo',
        home: MyHomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RemoterQuery<List<String>>(
          // remoterKey should be unique for each query
          remoterKey: "numbers",
          execute: () async {
            return List.generate(12, (index) => (index + 1).toString());
          },
          builder: (context, snapshot, utils) {
            if (snapshot.status == RemoterStatus.idle) {
              // You can skip this check if you don't use disabled parameter
            }
            if (snapshot.status == RemoterStatus.fetching) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.status == RemoterStatus.error) {
              return Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Text(
                      "Error occured",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton(
                        child: const Text("retry"),
                        onPressed: () {
                          utils.retry();
                        }),
                  ],
                ),
              );
            }
            // It is okay to use snapshot.data! here
            return Container(
              alignment: Alignment.topCenter,
              child: GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                children: snapshot.data!
                    .map(
                      (text) => Text(
                        text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }),
    );
  }
}
