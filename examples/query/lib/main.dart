import 'package:flutter/material.dart';
import 'package:flutter_remoter/flutter_remoter.dart';
import 'package:query/product.dart';
import 'package:query/utils/api.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
      body: RemoterQuery<List<SingleProduct>>(
          remoterKey: "products",
          execute: () async {
            final service = ProductService();
            final data = await service.getProducts();
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
              child: GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 300,
                ),
                children: snapshot.data!
                    .map(
                      (product) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: Image.network(product.images[0])),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  product.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => ProductPage(id: product.id),
                                    ),
                                  );
                                },
                                child: const Text("Details"),
                              ),
                            ],
                          ),
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
