// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedProductAdapter extends TypeAdapter<CachedProduct> {
  @override
  final int typeId = 0;

  @override
  CachedProduct read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedProduct(
      id: fields[0] as int,
      name: fields[1] as String,
      slug: fields[2] as String,
      description: fields[3] as String,
      shortDescription: fields[4] as String,
      price: fields[5] as String,
      regularPrice: fields[6] as String,
      salePrice: fields[7] as String,
      onSale: fields[8] as bool,
      featured: fields[9] as bool,
      imageUrls: (fields[10] as List).cast<String>(),
      categoryNames: (fields[11] as List).cast<String>(),
      averageRating: fields[12] as double,
      ratingCount: fields[13] as int,
      stockQuantity: fields[14] as int,
      stockStatus: fields[15] as String,
      cachedAt: fields[16] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedProduct obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.slug)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.shortDescription)
      ..writeByte(5)
      ..write(obj.price)
      ..writeByte(6)
      ..write(obj.regularPrice)
      ..writeByte(7)
      ..write(obj.salePrice)
      ..writeByte(8)
      ..write(obj.onSale)
      ..writeByte(9)
      ..write(obj.featured)
      ..writeByte(10)
      ..write(obj.imageUrls)
      ..writeByte(11)
      ..write(obj.categoryNames)
      ..writeByte(12)
      ..write(obj.averageRating)
      ..writeByte(13)
      ..write(obj.ratingCount)
      ..writeByte(14)
      ..write(obj.stockQuantity)
      ..writeByte(15)
      ..write(obj.stockStatus)
      ..writeByte(16)
      ..write(obj.cachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CacheMetadataAdapter extends TypeAdapter<CacheMetadata> {
  @override
  final int typeId = 1;

  @override
  CacheMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CacheMetadata(
      key: fields[0] as String,
      lastUpdated: fields[1] as DateTime,
      itemCount: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CacheMetadata obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.key)
      ..writeByte(1)
      ..write(obj.lastUpdated)
      ..writeByte(2)
      ..write(obj.itemCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
