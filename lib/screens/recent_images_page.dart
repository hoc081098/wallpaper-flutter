import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:disposebag/disposebag.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallpaper/data/database.dart';
import 'package:wallpaper/data/models/image_model.dart';
import 'package:wallpaper/screens/image_detail.dart';

class RecentPage extends StatefulWidget {
  final Stream<void> clearStream;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const RecentPage({Key key, this.clearStream, this.scaffoldKey})
      : super(key: key);

  @override
  _RecentPageState createState() => _RecentPageState();
}

abstract class _RecentItem {}

class _ImageItem implements _RecentItem {
  final ImageModel image;

  _ImageItem(this.image);
}

class _HeaderItem implements _RecentItem {
  final DateTime dateTime;

  _HeaderItem(this.dateTime);
}

class _RecentPageState extends State<RecentPage> {
  static final dateFormatYMdHms = DateFormat.yMd().add_Hms();
  static final dateFormatYMd = DateFormat.yMd();

  final disposeBag = DisposeBag();
  ValueStream<List<_RecentItem>> items$;

  @override
  void initState() {
    super.initState();

    final onDeleted = (int rows) {
      if (rows > 0) {
        widget.scaffoldKey.currentState.showSnackBar(
          SnackBar(
            content: Text('Delete successfully'),
          ),
        );
      }
    };
    widget.clearStream
        .asyncMap((_) => ImageDB.getInstance().deleteAllRecentImages())
        .listen(onDeleted)
        .disposedBy(disposeBag);

    items$ = ImageDB.getInstance()
        .getRecentImages()
        .map(createListWithHeader)
        .publishValueSeeded(null)
          ..connect().disposedBy(disposeBag);
  }

  @override
  void dispose() {
    disposeBag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_RecentItem>>(
      initialData: items$.value,
      stream: items$,
      builder: (context, snapshot) {
        final items = snapshot.data;

        if (items == null) {
          return Container(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
            color: Theme.of(context).backgroundColor,
          );
        }

        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Your list of history is empty',
                style: Theme.of(context).textTheme.headline6,
                textAlign: TextAlign.center,
              ),
            ),
            color: Theme.of(context).backgroundColor,
          );
        }

        final child = ListView.builder(
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];

            if (item is _HeaderItem) {
              final now = DateTime.now();
              final date = item.dateTime;

              if (now.difference(date).inDays < 1) {
                return ListTile(
                  title: Text(
                    'Today',
                    textScaleFactor: 1.1,
                  ),
                );
              }
              if (now.difference(date).inDays < 2) {
                return ListTile(
                  title: Text(
                    'Yesterday',
                    textScaleFactor: 1.1,
                  ),
                );
              }
              return ListTile(
                title: Text(
                  dateFormatYMd.format(date),
                  textScaleFactor: 1.1,
                ),
              );
            }

            if (item is _ImageItem) {
              return buildImageItem(item.image);
            }

            return null;
          },
          itemCount: items.length,
        );

        return Container(
          padding: const EdgeInsets.all(8.0),
          child: child,
          color: Theme.of(context).backgroundColor,
        );
      },
    );
  }

  Widget buildImageItem(ImageModel image) {
    final background = Container(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              'Delete',
              style: Theme.of(context).textTheme.subtitle1,
            ),
            SizedBox(width: 16.0),
            Icon(
              Icons.delete_sweep,
              size: 24.0,
            ),
          ],
        ),
      ),
    );

    final listTile = ListTile(
      leading: CachedNetworkImage(
        imageUrl: image.thumbnailUrl,
        fit: BoxFit.cover,
      ),
      title: Text(
        image.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        dateFormatYMdHms.format(image.viewTime),
        textScaleFactor: 0.8,
      ),
      trailing: IconButton(
        icon: Icon(Icons.close),
        tooltip: 'Remove history',
        onPressed: () => removeImage(image.id),
      ),
    );

    return Dismissible(
      background: background,
      key: Key(image.id),
      onDismissed: (_) => removeImage(image.id),
      child: GestureDetector(
        onTap: () => onTapImage(image),
        child: Container(
          color: Theme.of(context).primaryColorLight,
          child: listTile,
        ),
      ),
    );
  }

  void removeImage(String id) async {
    try {
      final rows = await ImageDB.getInstance().deleteRecentImageById(id);
      if (rows > 0) {
        widget.scaffoldKey.currentState.showSnackBar(
          SnackBar(content: Text('Delete successfully')),
        );
      } else {
        widget.scaffoldKey.currentState.showSnackBar(
          SnackBar(content: Text('Delete failed')),
        );
      }
    } catch (e) {
      widget.scaffoldKey.currentState.showSnackBar(
        SnackBar(content: Text('Delete error: $e')),
      );
    }
  }

  void onTapImage(ImageModel image) {
    final route = MaterialPageRoute(
      builder: (context) => ImageDetailPage(image),
    );
    Navigator.push(context, route);
  }

  static List<_RecentItem> createListWithHeader(List<ImageModel> images) {
    final items = <_RecentItem>[];

    DateTime prev;
    images.asMap().forEach((index, image) {
      final viewTime = image.viewTime;
      if (prev == null ||
          (prev.year != viewTime.year ||
              prev.month != viewTime.month ||
              prev.day != viewTime.day)) {
        final dateTime = DateTime(viewTime.year, viewTime.month, viewTime.day);
        items.add(_HeaderItem(dateTime));
        prev = dateTime;
      }
      items.add(_ImageItem(image));
    });

    return items;
  }
}
