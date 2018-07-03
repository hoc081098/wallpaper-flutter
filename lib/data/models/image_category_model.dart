import 'package:meta/meta.dart';

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
