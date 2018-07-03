import 'package:flutter/material.dart';
import 'package:wallpaper/data/database.dart';
import 'package:wallpaper/image_list.dart';

class RecentPage extends StatelessWidget {
  final imageDb = new ImageDb.getInstance();

  @override
  Widget build(BuildContext context) {
    return new ImageList(imageDb.getImages(20).asStream());
  }
}
