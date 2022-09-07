import 'package:flutter/material.dart';
import 'package:flutter_remoter/flutter_remoter.dart';

import 'api/facts.dart';

class NewPage extends StatelessWidget {
  const NewPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Text(
            "This page will instantly render data from previous page \n and trigger background refetch for each page (only if query is stale)",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          Expanded(
            child: PaginatedRemoterQuery<FactsPage>(
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
                          if (snapshot.data![0].previousPage != null)
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
                          if (snapshot
                                  .data![snapshot.data!.length - 1].nextPage !=
                              null)
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
          ),
        ],
      ),
    );
  }
}
