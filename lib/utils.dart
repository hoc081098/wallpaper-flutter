import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wallpaper/data/models/image_model.dart';

List<ImageModel> mapper(QuerySnapshot querySnapshot) {
  return querySnapshot.documents.map(mapperImageModel).toList();
}

ImageModel mapperImageModel(DocumentSnapshot documentSnapshot) {
  return ImageModel.fromJson(
    id: documentSnapshot.documentID,
    json: documentSnapshot.data,
  );
}

bool saveImage(Map<String, dynamic> map) {
  try {
    new File(map['filePath'])
      ..createSync(recursive: true)
      ..writeAsBytesSync(map['bytes']);
    return true;
  } catch (e) {
    return false;
  }
}
