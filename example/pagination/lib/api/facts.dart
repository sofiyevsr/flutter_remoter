import 'package:dio/dio.dart';

class SingleFact {
  final String fact;
  final int length;
  SingleFact({required this.fact, required this.length});
  factory SingleFact.fromJson(Map<String, dynamic> json) =>
      SingleFact(fact: json["fact"], length: json["length"]);
}

class FactsPage {
  final List<SingleFact> facts;
  final String? nextPage;
  final String? previousPage;

  FactsPage({
    required this.facts,
    required this.nextPage,
    required this.previousPage,
  });
}

class FactService {
  Future<FactsPage> getFacts([String? page]) async {
    /// For testing previousPage
    page = page ?? "4";
    final response = await Dio()
        .get("https://catfact.ninja/facts", queryParameters: {"page": page});
    final List<SingleFact> facts = [];
    for (int i = 0; i < response.data["data"].length; i++) {
      facts.add(SingleFact.fromJson(response.data["data"][i]));
    }
    final nextPage = response.data["next_page_url"];
    final previousPage = response.data["prev_page_url"];
    return FactsPage(
      facts: facts,
      nextPage:
          nextPage != null ? Uri.parse(nextPage).queryParameters["page"] : null,
      previousPage: previousPage != null
          ? Uri.parse(previousPage).queryParameters["page"]
          : null,
    );
  }
}
