<p align="center">
  <a href="https://www.codacy.com/gh/sofiyevsr/remoter/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=sofiyevsr/remoter&amp;utm_campaign=Badge_Grade"><img src="https://app.codacy.com/project/badge/Grade/b54f20951646419e83f875089eb13daa"/></a>
  <a href="https://www.codacy.com/gh/sofiyevsr/remoter/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=sofiyevsr/remoter&amp;utm_campaign=Badge_Coverage"><img src="https://app.codacy.com/project/badge/Coverage/b54f20951646419e83f875089eb13daa"/></a>
  <a href="https://github.com/sofiyevsr/remoter/actions/workflows/flutter_remoter.yml"><img src="https://img.shields.io/github/workflow/status/sofiyevsr/remoter/Flutter%20Remoter"/></a>
  <a href="https://pub.dev/packages/flutter_remoter"><img src="https://img.shields.io/pub/v/flutter_remoter?logo=dart"/></a>
  <img alt="GitHub top language" src="https://img.shields.io/github/languages/top/sofiyevsr/remoter">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT"></a>
</p>

---

Remoter aims to simplify handling asynchronous operations and revalidating them, inspired by [React Query](https://github.com/TanStack/query)

## Features

- Global and individual options
- Cache is collected after cache time if there is no listener
- Query is refetched if query is stale
- Fetch only once when multiple widget mounts at the same time
- Pagination
- Invalidate query
- Set query data manually

## Getting started

### Install dependencies

```yaml
dependencies:
  flutter_remoter: TODO
```

### Wrap your app with RemoterProvider

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoterProvider(
      client: RemoterClient(
        options: RemoterClientOptions(
            // default is 5 minutes
            // Use infinite staleTime if you don't need queries to be refetched when new query mounts
            // 1 << 31 is max int32
            // staleTime: 1 << 31,
            // default is 0ms, meaning queries are collected immediately after all listeners gone
            // cacheTime: 0,
            ),
      ),
      child: const MaterialApp(
        home: MyHomePage(),
      ),
    );
  }
}
```

## Usage

### Paginated Query

> See [full example](https://github.com/sofiyevsr/remoter/tree/master/examples/pagination)

```dart
    PaginatedRemoterQuery<FactsPage>(
          // remoterKey should be unique
          remoterKey: "facts",
          // Data returned from these functions will be passed
          // as param to execute function
          getNextPageParam: (pages) {
            return pages[pages.length - 1].nextPage;
          },
          getPreviousPageParam: (pages) {
            return pages[0].previousPage;
          },
          execute: (param) async {
            // Fetch data here
          },
          // Query won't start if this is true
          disabled: false,
          builder: (context, snapshot, utils) {
            if (snapshot.status == RemoterStatus.idle) {
              // You can skip this check if you don't use disabled parameter
            }
            if (snapshot.status == RemoterStatus.fetching) {
              // Handle fetching state here
            }
            if (snapshot.status == RemoterStatus.error) {
              // Handle error here
            }
            // It is okay to use snapshot.data! here
            return SingleChildScrollView(
              child: Column(
                children: [
                  if (snapshot.hasPreviousPage)
                    ElevatedButton(
                      onPressed: () {
                        utils.fetchPreviousPage();
                      },
                      child: snapshot.isFetchingPreviousPage == true
                          ? const CircularProgressIndicator(
                                color: Colors.white,
                            )
                          : const Text("Load previous"),
                    ),
                  ...snapshot.data!
                      .expand((el) => el.facts)
                      .map(
                        (d) => Text(d.fact),
                      )
                      .toList(),
                  if (snapshot.hasNextPage)
                    ElevatedButton(
                      onPressed: () {
                        utils.fetchNextPage();
                      },
                      child: snapshot.isFetchingNextPage == true
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text("Load more"),
                    ),
                ],
              ),
            );
          })

```
