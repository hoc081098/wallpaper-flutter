import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

class ImageModel {
  final String id;
  final String name;
  final String imageUrl;
  final String thumbnailUrl;
  final String categoryId;
  final Timestamp uploadedTime;

  ///
  DateTime viewTime;

  ImageModel({
    this.id,
    this.name,
    this.imageUrl,
    this.thumbnailUrl,
    this.categoryId,
    this.uploadedTime,
    this.viewTime,
  });

  factory ImageModel.fromJson({
    @required String id,
    @required Map<String, dynamic> json,
  }) {
    print(json);

    return ImageModel(
      id: id,
      name: json['name'],
      imageUrl: json['imageUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      categoryId: json['categoryId'],
      uploadedTime: () {
        final uploadedTime = json['uploadedTime'];

        if (uploadedTime is Timestamp) {
          return uploadedTime;
        }
        if (uploadedTime is String) {
          return Timestamp.fromDate(DateTime.parse(uploadedTime));
        }
        return Timestamp.now();
      }(),
      viewTime: DateTime.tryParse(json['viewTime'] ?? ''),
    );
  }

  Map<String, String> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'thumbnailUrl': thumbnailUrl,
    'categoryId': categoryId,
    'uploadedTime': uploadedTime.toDate().toIso8601String(),
    'viewTime': viewTime.toIso8601String()
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ImageModel && runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ImageModel{id: $id, name: $name, imageUrl: $imageUrl,'
      ' thumbnailUrl: $thumbnailUrl, categoryId: $categoryId, uploadedTime: $uploadedTime, viewTime: $viewTime}';
}
