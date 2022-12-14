<p align="center">
  <a href="https://www.codacy.com/gh/sofiyevsr/flutter_remoter/dashboard"><img src="https://app.codacy.com/project/badge/Grade/b54f20951646419e83f875089eb13daa"/></a>
  <a href="https://www.codacy.com/gh/sofiyevsr/flutter_remoter/dashboard"><img src="https://app.codacy.com/project/badge/Coverage/b54f20951646419e83f875089eb13daa"/></a>
  <a href="https://github.com/sofiyevsr/flutter_remoter/actions/workflows/flutter_remoter.yml"><img src="https://img.shields.io/github/actions/workflow/status/sofiyevsr/flutter_remoter/flutter_remoter.yml"/></a>
  <a href="https://pub.dev/packages/flutter_remoter"><img src="https://img.shields.io/pub/v/flutter_remoter?logo=dart"/></a>
  <img alt="GitHub top language" src="https://img.shields.io/github/languages/top/sofiyevsr/flutter_remoter">
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
- Retry query when new widget mounts
- Auto retry with exponential backoff
- Mutation widget

## Getting started

### Install dependencies

```yaml
dependencies:
  flutter_remoter: ^0.2.0
```

### Wrap your app with RemoterProvider

RemoterProvider expects a RemoterClient which you can export from package and use everywhere without context.

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoterProvider(
      client: RemoterClient(
        // This line defines default options for all queries
        // You can override options in each query
        options: RemoterOptions(
            // staleTime defines how many ms after query fetched can be refetched
            // Use infinite staleTime if you don't need queries to be refetched when new query mounts
            // 1 << 31 is max int32
            // default is 0ms
            staleTime: 0,
            // cacheTime defines how many ms after all listeners are gone query data should be cleared,
            // default is 5 minutes
            cacheTime: 5 * 60 * 1000,
            // Maximum delay between retries in ms
            maxDelay: 5 * 60 * 1000,
            // Maximum amount of retries
            maxRetries: 3,
            // Flag that decides if query that has error status should be refetched on mount
            retryOnMount: true,
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

There are three types of widgets: RemoterQuery, PaginatedRemoterQuery and RemoterMutation.

### Remoter Query

Used for 'single page' data

> See [full example](https://github.com/sofiyevsr/flutter_remoter/tree/master/examples/query)

```dart
    RemoterQuery<T>(
      remoterKey: "key",
      listener: (oldState, newState) async {
        // Optional state listener
      },
      execute: () async {
        // Fetch data here
      },
      // Override default options defined in RemoterClient
      // You don't have to copy the fields you don't want to override
      // e.g Default is RemoterOptions(cacheTime: 2000, staleTime: 1000).
      // You want to override staleTime for specific query, use RemoterOptions(staleTime: 1000).
      // In this case cacheTime won't be overriden and will still be 2000
      options: RemoterOptions(),
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
        return ...
      },
    )
```

### Paginated Remoter Query

Used for data that has multiple pages or "infinite scroll" like experience.

> See [full example](https://github.com/sofiyevsr/flutter_remoter/tree/master/examples/pagination)

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
          // Override default options defined in RemoterClient
          // You don't have to copy the fields you don't want to override
          // e.g Default is RemoterOptions(cacheTime: 2000, staleTime: 1000).
          // You want to override staleTime for specific query, use RemoterOptions(staleTime: 1000).
          // In this case cacheTime won't be overriden and will still be 2000
          options: RemoterOptions(),
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

### Remoter Mutation

Used to simplify handling asynchronous calls\
T represents type of the value execute function returns\
S represents type of the value passed to mutate function which will be passed to execute function as parameter

> See [example](https://github.com/sofiyevsr/flutter_remoter/tree/master/examples/counter_app_mutation)

```dart
  RemoterMutation<T, S>(
   execute: (param) async {
     await Future.delayed(const Duration(seconds: 1));
     return ...
   },
   builder: (context, snapshot, utils) {
          if (snapshot.status == RemoterStatus.idle) {
            // Mutation hasn't started yet
          }
          if (snapshot.status == RemoterStatus.fetching) {
            // Handle fetching state here
          }
          if (snapshot.status == RemoterStatus.error) {
            // Handle error here
          }
          // It is okay to use snapshot.data! here
          return Text(
           snapshot.data!,
          );
       },
       floatingActionButton: FloatingActionButton(
         onPressed: snapshot.status == RemoterStatus.fetching
             ? null
             : () {
                 // Starts mutation
                 // In this case null will be passed to execute as param
                 utils.mutate(null);
               },
         child: const Icon(Icons.add),
       ),
     );
  });
```

### Using RemoterClient

There are 2 ways to retrieve RemoterClient

## With BuildContext

```dart
   RemoterProvider.of(context).client
```

## Without BuildContext

To use RemoterClient without context, you can create RemoterClient in separate file.\
Then that instance should be use with RemoterProvider which wraps the App.\
Finally, you can import and use the instance anywhere in your app.

```dart
import 'path to RemoterClient instance';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoterProvider(
      // 'client' is the instance from import
      client: client,
      child: const MaterialApp(
        home: MyHomePage(),
      ),
    );
  }
}
```
