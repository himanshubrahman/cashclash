import 'dart:convert';
import 'package:http/http.dart' as http;

class FinnhubService {
  static const apiKey = "d4v15j1r01qnm7pos7m0d4v15j1r01qnm7pos7mg";
  static const baseUrl = "https://finnhub.io/api/v1";

  static Future<List<Map<String, dynamic>>> searchSymbols(String query) async {
    if (query.length < 2) return [];
    final url = Uri.parse('$baseUrl/search?q=$query&token=$apiKey');
    final res = await http.get(url);
    final data = json.decode(res.body);
    return List<Map<String, dynamic>>.from(data['result'] ?? []);
  }

  static Future<double> getPrice(String symbol) async {
    final url = Uri.parse('$baseUrl/quote?symbol=$symbol&token=$apiKey');
    final res = await http.get(url);
    final data = json.decode(res.body);
    return (data['c'] ?? 0).toDouble();
  }
}
