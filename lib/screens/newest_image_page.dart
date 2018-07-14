import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallpaper/image_list.dart';
import 'package:wallpaper/utils.dart';

class NewestPage extends StatelessWidget {
  final imagesCollection = Firestore.instance.collection('images');

  @override
  Widget build(BuildContext context) {
    return new StaggeredImageList(
      imagesCollection
          .orderBy('uploadedTime', descending: true)
          .limit(15)
          .snapshots()
          .map(mapper),
    );
  }
}
