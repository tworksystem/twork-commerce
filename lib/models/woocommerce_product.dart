import 'package:ecommerce_int2/utils/price_formatter.dart';

import 'product.dart';

class WooCommerceProduct {
  final int id;
  final String name;
  final String slug;
  final String permalink;
  final String dateCreated;
  final String dateModified;
  final String type;
  final String status;
  final bool featured;
  final String catalogVisibility;
  final String description;
  final String shortDescription;
  final String sku;
  final String price;
  final String regularPrice;
  final String salePrice;
  final bool onSale;
  final bool purchasable;
  final int totalSales;
  final bool virtual;
  final bool downloadable;
  final String taxStatus;
  final String taxClass;
  final bool manageStock;
  final int? stockQuantity;
  final String backorders;
  final bool backordersAllowed;
  final bool backordered;
  final bool soldIndividually;
  final String weight;
  final Dimensions dimensions;
  final bool shippingRequired;
  final bool shippingTaxable;
  final String shippingClass;
  final int shippingClassId;
  final bool reviewsAllowed;
  final String averageRating;
  final int ratingCount;
  final List<int> upsellIds;
  final List<int> crossSellIds;
  final int parentId;
  final String purchaseNote;
  final List<Category> categories;
  final List<dynamic> brands;
  final List<dynamic> tags;
  final List<WooCommerceImage> images;
  final List<dynamic> attributes;
  final List<dynamic> defaultAttributes;
  final List<dynamic> variations;
  final List<dynamic> groupedProducts;
  final int menuOrder;
  final String priceHtml;
  final List<int> relatedIds;
  final List<MetaData> metaData;
  final String stockStatus;
  final bool hasOptions;
  final String postPassword;
  final String globalUniqueId;

  WooCommerceProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.permalink,
    required this.dateCreated,
    required this.dateModified,
    required this.type,
    required this.status,
    required this.featured,
    required this.catalogVisibility,
    required this.description,
    required this.shortDescription,
    required this.sku,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.onSale,
    required this.purchasable,
    required this.totalSales,
    required this.virtual,
    required this.downloadable,
    required this.taxStatus,
    required this.taxClass,
    required this.manageStock,
    this.stockQuantity,
    required this.backorders,
    required this.backordersAllowed,
    required this.backordered,
    required this.soldIndividually,
    required this.weight,
    required this.dimensions,
    required this.shippingRequired,
    required this.shippingTaxable,
    required this.shippingClass,
    required this.shippingClassId,
    required this.reviewsAllowed,
    required this.averageRating,
    required this.ratingCount,
    required this.upsellIds,
    required this.crossSellIds,
    required this.parentId,
    required this.purchaseNote,
    required this.categories,
    required this.brands,
    required this.tags,
    required this.images,
    required this.attributes,
    required this.defaultAttributes,
    required this.variations,
    required this.groupedProducts,
    required this.menuOrder,
    required this.priceHtml,
    required this.relatedIds,
    required this.metaData,
    required this.stockStatus,
    required this.hasOptions,
    required this.postPassword,
    required this.globalUniqueId,
  });

  factory WooCommerceProduct.fromJson(Map<String, dynamic> json) {
    return WooCommerceProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      permalink: json['permalink'] ?? '',
      dateCreated: json['date_created'] ?? '',
      dateModified: json['date_modified'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      featured: json['featured'] ?? false,
      catalogVisibility: json['catalog_visibility'] ?? '',
      description: json['description'] ?? '',
      shortDescription: json['short_description'] ?? '',
      sku: json['sku'] ?? '',
      price: json['price'] ?? '',
      regularPrice: json['regular_price'] ?? '',
      salePrice: json['sale_price'] ?? '',
      onSale: json['on_sale'] ?? false,
      purchasable: json['purchasable'] ?? false,
      totalSales: json['total_sales'] ?? 0,
      virtual: json['virtual'] ?? false,
      downloadable: json['downloadable'] ?? false,
      taxStatus: json['tax_status'] ?? '',
      taxClass: json['tax_class'] ?? '',
      manageStock: json['manage_stock'] ?? false,
      stockQuantity: json['stock_quantity'],
      backorders: json['backorders'] ?? '',
      backordersAllowed: json['backorders_allowed'] ?? false,
      backordered: json['backordered'] ?? false,
      soldIndividually: json['sold_individually'] ?? false,
      weight: json['weight'] ?? '',
      dimensions: Dimensions.fromJson(json['dimensions'] ?? {}),
      shippingRequired: json['shipping_required'] ?? false,
      shippingTaxable: json['shipping_taxable'] ?? false,
      shippingClass: json['shipping_class'] ?? '',
      shippingClassId: json['shipping_class_id'] ?? 0,
      reviewsAllowed: json['reviews_allowed'] ?? false,
      averageRating: json['average_rating'] ?? '0.00',
      ratingCount: json['rating_count'] ?? 0,
      upsellIds: List<int>.from(json['upsell_ids'] ?? []),
      crossSellIds: List<int>.from(json['cross_sell_ids'] ?? []),
      parentId: json['parent_id'] ?? 0,
      purchaseNote: json['purchase_note'] ?? '',
      categories: (json['categories'] as List?)
              ?.map((x) => Category.fromJson(x))
              .toList() ??
          [],
      brands: json['brands'] ?? [],
      tags: json['tags'] ?? [],
      images: (json['images'] as List?)
              ?.map((x) => WooCommerceImage.fromJson(x))
              .toList() ??
          [],
      attributes: json['attributes'] ?? [],
      defaultAttributes: json['default_attributes'] ?? [],
      variations: json['variations'] ?? [],
      groupedProducts: json['grouped_products'] ?? [],
      menuOrder: json['menu_order'] ?? 0,
      priceHtml: json['price_html'] ?? '',
      relatedIds: List<int>.from(json['related_ids'] ?? []),
      metaData: (json['meta_data'] as List?)
              ?.map((x) => MetaData.fromJson(x))
              .toList() ??
          [],
      stockStatus: json['stock_status'] ?? '',
      hasOptions: json['has_options'] ?? false,
      postPassword: json['post_password'] ?? '',
      globalUniqueId: json['global_unique_id'] ?? '',
    );
  }

  // Helper method to get display price
  String get displayPrice {
    if (onSale && salePrice.isNotEmpty) {
      return salePrice;
    } else if (regularPrice.isNotEmpty) {
      return regularPrice;
    } else if (price.isNotEmpty) {
      return price;
    }
    return '0.00';
  }

  // Helper method to get formatted price
  String get formattedPrice => PriceFormatter.formatFromString(displayPrice);

  // Helper method to get first image URL
  String get firstImageUrl {
    if (images.isNotEmpty) {
      return images.first.src;
    }
    return ''; // Return empty string if no images
  }

  // Helper method to get clean description
  String get cleanDescription {
    // Remove HTML tags and clean up the description
    String cleanDesc = description
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();

    if (cleanDesc.isEmpty && shortDescription.isNotEmpty) {
      cleanDesc = shortDescription
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .trim();
    }

    return cleanDesc.isEmpty ? 'No description available' : cleanDesc;
  }

  // Convert to the existing Product model for compatibility
  Product toProduct() {
    final productImage = firstImageUrl.isNotEmpty
        ? firstImageUrl
        : 'assets/headphones.png'; // Use existing asset as fallback

    final categoryIdList = categories.map((category) => category.id).toList();

    final additionalDetails = <String, dynamic>{
      'permalink': permalink,
      'priceHtml': priceHtml,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'stockStatus': stockStatus,
      'type': type,
      'onSale': onSale,
      'currencyPrice': displayPrice,
    };

    return Product(
      productImage,
      name,
      cleanDescription,
      double.tryParse(displayPrice) ?? 0.0,
      id: id,
      slug: slug,
      categoryIds: categoryIdList,
      extra: additionalDetails,
    );
  }
}

class Dimensions {
  final String length;
  final String width;
  final String height;

  Dimensions({
    required this.length,
    required this.width,
    required this.height,
  });

  factory Dimensions.fromJson(Map<String, dynamic> json) {
    return Dimensions(
      length: json['length'] ?? '',
      width: json['width'] ?? '',
      height: json['height'] ?? '',
    );
  }
}

class Category {
  final int id;
  final String name;
  final String slug;

  Category({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
    );
  }
}

class WooCommerceImage {
  final int id;
  final String src;
  final String name;
  final String alt;

  WooCommerceImage({
    required this.id,
    required this.src,
    required this.name,
    required this.alt,
  });

  factory WooCommerceImage.fromJson(Map<String, dynamic> json) {
    return WooCommerceImage(
      id: json['id'] ?? 0,
      src: json['src'] ?? '',
      name: json['name'] ?? '',
      alt: json['alt'] ?? '',
    );
  }
}

class MetaData {
  final int id;
  final String key;
  final dynamic value;

  MetaData({
    required this.id,
    required this.key,
    required this.value,
  });

  factory MetaData.fromJson(Map<String, dynamic> json) {
    return MetaData(
      id: json['id'] ?? 0,
      key: json['key'] ?? '',
      value: json['value'],
    );
  }
}
