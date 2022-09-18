import 'package:flutter/material.dart';
import 'package:flutter_remoter/flutter_remoter.dart';
import 'package:infinite_scroll/utils/api.dart';
import 'package:infinite_scroll/utils/client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: RemoterProvider(
        client: remoterClient,
        child: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll - currentScroll <= 300) {
        // Client can also be retrieved by RemoterProvider.of(context).client
        remoterClient.fetchNextPage<FactsPage>("facts");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaginatedRemoterQuery<FactsPage>(
          remoterKey: "facts",
          getNextPageParam: (pages) {
            return pages[pages.length - 1].nextPage;
          },
          execute: (param) async {
            final service = FactService();
            final data = await service.getFacts(param?.value);
            return data;
          },
          builder: (context, snapshot, utils) {
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
                      onPressed: utils.retry,
                      child: const Text("retry"),
                    ),
                  ],
                ),
              );
            }
            return Container(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...snapshot.data!
                        .expand((el) => el.facts)
                        .map(
                          (d) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(d.fact),
                            ),
                          ),
                        )
                        .toList(),
                    if (snapshot.isFetchingNextPage)
                      Container(
                        height: 80,
                        padding: const EdgeInsets.all(10),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: Colors.blue,
                        ),
                      )
                    else if (snapshot.isNextPageError)
                      Container(
                        height: 80,
                        alignment: Alignment.center,
                        child: ElevatedButton(
                          onPressed: utils.fetchNextPage,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            child: const Text("Retry"),
                          ),
                        ),
                      )
                  ],
                ),
              ),
            );
          }),
    );
  }
}
