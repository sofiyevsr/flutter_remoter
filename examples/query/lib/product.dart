import 'package:flutter/material.dart';
import 'package:flutter_remoter/flutter_remoter.dart';

import 'utils/api.dart';

class ProductPage extends StatelessWidget {
  final int id;
  const ProductPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: RemoterQuery<SingleProduct>(
          remoterKey: "products/$id",
          execute: () async {
            final service = ProductService();
            final data = await service.getProduct(id);
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
                      },
                    ),
                  ],
                ),
              );
            }
            return Container(
              alignment: Alignment.topCenter,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Image.network(
                          snapshot.data!.images[0],
                        ),
                      ),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              snapshot.data!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            Text(
                              snapshot.data!.description,
                              style: const TextStyle(
                                fontSize: 24,
                              ),
                            ),
                            Text(
                              "${snapshot.data!.price.toString()}\$",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
    );
  }
}
