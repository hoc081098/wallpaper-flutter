import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
    File(map['filePath'])
      ..createSync(recursive: true)
      ..writeAsBytesSync(map['bytes']);
    return true;
  } catch (e) {
    print('Saved image error: $e');
    return false;
  }
}

void showProgressDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children:  <Widget>[
              const CircularProgressIndicator(),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(message),
              ),
            ],
          ),
        ),
      );
    },
  );
}
