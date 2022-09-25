import 'package:dio/dio.dart';

class SingleProduct {
  int id;
  String title;
  String description;
  int price;
  List<dynamic> images;
  SingleProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
  });
  factory SingleProduct.fromJson(Map<String, dynamic> json) => SingleProduct(
        id: json["id"],
        title: json["title"],
        description: json["description"],
        price: json["price"],
        images: json["images"],
      );
}

class ProductService {
  Future<List<SingleProduct>> getProducts() async {
    final response = await Dio().get("https://dummyjson.com/products");
    final List<SingleProduct> products = [];
    for (int i = 0; i < response.data["products"].length; i++) {
      products.add(SingleProduct.fromJson(response.data["products"][i]));
    }
    return products;
  }

  Future<SingleProduct> getProduct(int id) async {
    final response = await Dio().get("https://dummyjson.com/products/$id");
    return SingleProduct.fromJson(response.data);
  }
}
