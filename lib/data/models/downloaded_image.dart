class DownloadedImage {
  final String id;
  final String name;
  final String imageUrl;
  final DateTime createdAt;

  DownloadedImage(
    this.id,
    this.name,
    this.imageUrl,
    this.createdAt,
  );

  factory DownloadedImage.fromJson(Map<String, dynamic> json) {
    return DownloadedImage(
      json['id'],
      json['name'],
      json['imageUrl'],
      DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'DownloadedImage{id: $id, name: $name, imageUrl: $imageUrl, createdAt: $createdAt}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadedImage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          imageUrl == other.imageUrl &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ imageUrl.hashCode ^ createdAt.hashCode;
}
