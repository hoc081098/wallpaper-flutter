import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

class _RecentPageState extends State<RecentPage> {
  static final dateFormatYMdHms = DateFormat.yMd().add_Hms();
  static final dateFormatYMd = DateFormat.yMd();
  final imageDB = ImageDB.getInstance();

  List<ImageModel> _images;
  List<Map<String, dynamic>> _imagesWithHeaders;
  StreamSubscription subscription;

  @override
  void initState() {
    super.initState();
    subscription = widget.clearStream
        .asyncMap((_) => imageDB.deleteAllRecentImages())
        .listen(_onData);
    _getRecentImages();
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  void _getRecentImages() {
    imageDB
        .getRecentImages()
        .then((v) => _images = v)
        .then(createListWithHeader)
        .then((v) => setState(() => _imagesWithHeaders = v));
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(':H: build');

    if (_imagesWithHeaders == null) {
      return Container(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
        color: Theme.of(context).backgroundColor,
      );
    }

    if (_imagesWithHeaders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Text(
            'Your list of history is empty',
            style: Theme.of(context).textTheme.title,
          ),
        ),
        color: Theme.of(context).backgroundColor,
      );
    }

    final child = ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        final item = _imagesWithHeaders[index];

        if (item['type'] == 'header') {
          final now = DateTime.now();
          final date = item['date'];

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

        if (item['type'] == 'image') {
          return _buildItem(item['image'], item['index']);
        }

        return null;
      },
      itemCount: _imagesWithHeaders.length,
    );

    return Container(
      padding: const EdgeInsets.all(8.0),
      child: child,
      color: Theme.of(context).backgroundColor,
    );
  }

  List<Map<String, dynamic>> createListWithHeader(List<ImageModel> images) {
    DateTime prev;
    final result = <Map<String, dynamic>>[];

    images.asMap().forEach((index, img) {
      debugPrint('DEBUG: $prev');
      final viewTime = img.viewTime;
      if (prev == null ||
          (prev.year != viewTime.year ||
              prev.month != viewTime.month ||
              prev.day != viewTime.day)) {
        final dateTime = DateTime(viewTime.year, viewTime.month, viewTime.day);
        result.add({
          'type': 'header',
          'date': dateTime,
        });
        prev = dateTime;
      }

      result.add({
        'type': 'image',
        'image': img,
        'index': index,
      });
    });
    return result;
  }

  Widget _buildItem(ImageModel image, int index) {
    final background = Container(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              'Delete',
              style: Theme.of(context).textTheme.subhead,
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
        onPressed: () => _remove(image.id, index),
      ),
    );

    return Dismissible(
      background: background,
      key: Key(image.id),
      onDismissed: (_) => _remove(image.id, index),
      child: GestureDetector(
        onTap: () => _onTap(image),
        child: Container(
          color: Theme.of(context).primaryColorLight,
          child: listTile,
        ),
      ),
    );
  }

  void _onData(int event) {
    setState(() {
      _images = [];
      _imagesWithHeaders = [];
    });
    widget.scaffoldKey.currentState.showSnackBar(
      SnackBar(content: Text('Delete successfully')),
    );
  }

  _remove(String id, int index) {
    imageDB.deleteRecentImageById(id).then((i) {
      if (i > 0) {
        widget.scaffoldKey.currentState.showSnackBar(
          SnackBar(content: Text('Delete successfully')),
        );

        setState(() {
          _images.removeAt(index);
          _imagesWithHeaders = createListWithHeader(_images);
        });
      } else {
        widget.scaffoldKey.currentState.showSnackBar(
          SnackBar(content: Text('Delete failed')),
        );
      }
    }).catchError(
      (e) => widget.scaffoldKey.currentState.showSnackBar(
        SnackBar(content: Text('Delete error: $e')),
      ),
    );
  }

  _onTap(ImageModel image) async {
    final route = MaterialPageRoute(
      builder: (context) => ImageDetailPage(image),
    );
    await Navigator.push(context, route);
    _getRecentImages();
  }
}
