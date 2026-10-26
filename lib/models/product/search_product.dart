import 'dart:convert';

class SearchProduct {
  SearchProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.imageUrl,
    this.model,
    this.engineCapacity,
    this.year,
  });

  final String id;
  final String name;
  final double price;
  final String currency;
  final String imageUrl;
  final String? model;
  final String? engineCapacity;
  final String? year;

  factory SearchProduct.fromJson(Map<String, dynamic> json) {
    return SearchProduct(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'بدون اسم',
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'LYD',
      imageUrl: json['image']?.toString() ?? '',
      model: json['model']?.toString(),
      engineCapacity: json['engine_capacity']?.toString(),
      year: json['year']?.toString(),
    );
  }

  static List<SearchProduct> listFromResponse(String body) {
    final decoded = json.decode(body);
    if (decoded is List) {
      return decoded
          .map(
            (item) =>
                SearchProduct.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    }
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .map(
            (item) => SearchProduct.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }
    return [];
  }

  String get formattedPrice =>
      price == 0 ? 'غير متاح' : '${price.toStringAsFixed(0)} $currency';
}
