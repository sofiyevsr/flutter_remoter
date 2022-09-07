import 'package:flutter/material.dart';
import 'package:flutter_remoter/flutter_remoter.dart';
import 'package:pagination/api/facts.dart';

import 'new_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoterProvider(
      client: RemoterClient(
        options: RemoterClientOptions(
            // Infinite staleTime means it won't be refetched on startup
            // 1 << 31 is max int32
            // staleTime: 1 << 31,
            // 0 cacheTime means query will be cleared after 0 ms after all listeners gone
            // cacheTime: 0,
            ),
      ),
      child: const MaterialApp(
        title: 'Remoter Demo',
        home: MyHomePage(title: 'Remoter Demo Home Page'),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NewPage(),
                ),
              );
            },
            child: const Text("go to new page"),
          ),
        ],
      ),
      body: PaginatedRemoterQuery<FactsPage>(
          remoterKey: "facts",
          getNextPageParam: (pages) {
            return pages[pages.length - 1].nextPage;
          },
          getPreviousPageParam: (pages) {
            return pages[0].previousPage;
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
                        child: const Text("retry"),
                        onPressed: () {
                          utils.retry();
                        }),
                  ],
                ),
              );
            }
            return Container(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot.hasPreviousPage)
                      Container(
                        alignment: Alignment.center,
                        child: ElevatedButton(
                          onPressed: () {
                            utils.fetchPreviousPage();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            child: snapshot.isFetchingPreviousPage == true
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text("Load previous"),
                          ),
                        ),
                      ),
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
                    if (snapshot.hasNextPage)
                      Container(
                        alignment: Alignment.center,
                        child: ElevatedButton(
                          onPressed: () {
                            utils.fetchNextPage();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            child: snapshot.isFetchingNextPage == true
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text("Load more"),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
    );
  }
}
