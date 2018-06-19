import 'package:meta/meta.dart';

class ImageModel {
  final String id;
  final String name;
  final String imageUrl;
  final String thumbnailUrl;
  final String categoryId;
  final DateTime uploadedTime;

  ImageModel({
    this.id,
    this.name,
    this.imageUrl,
    this.thumbnailUrl,
    this.categoryId,
    this.uploadedTime,
  });

  factory ImageModel.fromJson(
      {@required String id, @required Map<String, dynamic> json}) {
    return ImageModel(
      id: id,
      name: json['name'],
      imageUrl: json['imageUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      categoryId: json['categoryId'],
      uploadedTime: json['uploadedTime'],
    );
  }

  @override
  String toString() => 'ImageModel{id: $id, name: $name,'
      ' imageUrl: $imageUrl, thumbnailUrl: $thumbnailUrl, categoryId: $categoryId}';
}

class ImageCategory {
  final String id;
  final String name;
  final String imageUrl;

  ImageCategory({this.id, this.name, this.imageUrl});

  factory ImageCategory.fromJson(
      {@required String id, @required Map<String, dynamic> json}) {
    return ImageCategory(
      id: id,
      name: json['name'],
      imageUrl: json['imageUrl'],
    );
  }

  @override
  String toString() =>
      'ImageCategory{id: $id, name: $name, imageUrl: $imageUrl}';
}
