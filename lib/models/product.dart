import 'package:ecommerce_int2/utils/price_formatter.dart';
import 'package:ecommerce_int2/models/woocommerce_product.dart';

class Product {
  final String image;
  final String name;
  final String description;
  final double price;
  final int? id;
  final String? slug;
  final List<int> categoryIds;
  final Map<String, dynamic>? extra;

  const Product(
    this.image,
    this.name,
    this.description,
    this.price, {
    this.id,
    this.slug,
    List<int>? categoryIds,
    this.extra,
  }) : categoryIds = categoryIds ?? const [];

  // Helper method to get formatted price
  String get formattedPrice => PriceFormatter.format(price);

  // Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'image': image,
      'name': name,
      'description': description,
      'price': price,
      'id': id,
      'slug': slug,
      'categoryIds': categoryIds,
      'extra': extra,
    };
  }

  // Create from WooCommerce product
  factory Product.fromWooCommerce(WooCommerceProduct wooProduct) {
    return wooProduct.toProduct();
  }

  // Create from JSON for caching
  factory Product.fromJson(Map<String, dynamic> json) {
    final dynamic rawCategoryIds = json['categoryIds'];
    final List<int> parsedCategoryIds;
    if (rawCategoryIds is List) {
      parsedCategoryIds = rawCategoryIds
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false);
    } else {
      parsedCategoryIds = const [];
    }

    final extraData = json['extra'];
    return Product(
      json['image'] as String? ?? '',
      json['name'] as String? ?? '',
      json['description'] as String? ?? '',
      (json['price'] as num?)?.toDouble() ?? 0.0,
      id: (json['id'] as num?)?.toInt(),
      slug: json['slug'] as String?,
      categoryIds: parsedCategoryIds,
      extra: extraData is Map<String, dynamic>
          ? Map<String, dynamic>.from(extraData)
          : null,
    );
  }

  Product copyWith({
    String? image,
    String? name,
    String? description,
    double? price,
    int? id,
    String? slug,
    List<int>? categoryIds,
    Map<String, dynamic>? extra,
  }) {
    return Product(
      image ?? this.image,
      name ?? this.name,
      description ?? this.description,
      price ?? this.price,
      id: id ?? this.id,
      slug: slug ?? this.slug,
      categoryIds: categoryIds ?? this.categoryIds,
      extra: extra ?? this.extra,
    );
  }
}
