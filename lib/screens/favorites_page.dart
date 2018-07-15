import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallpaper/data/database.dart';
import 'package:wallpaper/data/models/image_model.dart';
import 'package:wallpaper/image_list.dart';

class FavoritesPage extends StatelessWidget {
  final Observable<String> sortOrderStream;

  FavoritesPage(this.sortOrderStream);

  @override
  Widget build(BuildContext context) {
    return new Container(
      color: Theme.of(context).backgroundColor,
      child: new StreamBuilder(
        stream: sortOrderStream.switchMap(
          (order) => Stream.fromFuture(
                new ImageDB.getInstance().getFavoriteImages(orderBy: order),
              ),
        ),
        builder:
            (BuildContext context, AsyncSnapshot<List<ImageModel>> snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: Theme.of(context).textTheme.title,
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          var images = snapshot.data;

          if (images.isEmpty) {
            return Center(
              child: Text(
                'Your favorites is empty',
                style: Theme.of(context).textTheme.title,
              ),
            );
          }

          return new GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 9 / 16,
            ),
            itemBuilder: (BuildContext context, int index) {
              return ImageItem(images[index]);
            },
            itemCount: images.length,
          );
        },
      ),
    );
  }
}
