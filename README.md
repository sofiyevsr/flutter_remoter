<p align="center">
  <a href="https://www.codacy.com/gh/sofiyevsr/remoter/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=sofiyevsr/remoter&amp;utm_campaign=Badge_Grade"><img src="https://app.codacy.com/project/badge/Grade/b54f20951646419e83f875089eb13daa"/></a>
  <a href="https://www.codacy.com/gh/sofiyevsr/remoter/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=sofiyevsr/remoter&amp;utm_campaign=Badge_Coverage"><img src="https://app.codacy.com/project/badge/Coverage/b54f20951646419e83f875089eb13daa"/></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT"></a>
</p>

---

Remoter aims to simplify handling asynchronous operations and revalidating them, inspired by [React Query](https://github.com/TanStack/query)

| Package                                                                                    |                                                      Version                                                       |
| ------------------------------------------------------------------------------------------ | :----------------------------------------------------------------------------------------------------------------: |
| [remoter](https://github.com/sofiyevsr/remoter/tree/main/packages/remoter)                 |         [![Pub Version](https://img.shields.io/pub/v/remoter?logo=dart)](https://pub.dev/packages/remoter)         |
| [flutter_remoter](https://github.com/sofiyevsr/remoter/tree/main/packages/flutter_remoter) | [![Pub Version](https://img.shields.io/pub/v/flutter_remoter?logo=dart)](https://pub.dev/packages/flutter_remoter) |

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
  remoter: ^1.0.0
  flutter_remoter: ^1.0.0
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
            // Infinite staleTime means it won't be refetched on startup
            // default is 5 minutes
            // 1 << 31 is max int32
            // staleTime: 1 << 31,
            // 0 cacheTime means query will be cleared after 0 ms after all listeners gone
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

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder.

```dart
const like = 'sample';
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
