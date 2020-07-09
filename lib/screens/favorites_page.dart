import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallpaper/data/database.dart';
import 'package:wallpaper/data/models/image_model.dart';
import 'package:wallpaper/image_list.dart';

@immutable
class FavoritesPage extends StatelessWidget {
  final Stream<String> sortOrderStream;

  const FavoritesPage(this.sortOrderStream);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).backgroundColor,
      child: StreamBuilder<List<ImageModel>>(
        stream: sortOrderStream.distinct().switchMap(
            (order) => ImageDB.getInstance().getFavoriteImages(orderBy: order)),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: Theme.of(context).textTheme.headline6,
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          final images = snapshot.data;

          if (images.isEmpty) {
            return Center(
              child: Text(
                'Your favorites is empty',
                style: Theme.of(context).textTheme.headline6,
                textAlign: TextAlign.center,
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
