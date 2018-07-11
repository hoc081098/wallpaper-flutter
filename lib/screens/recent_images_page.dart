import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallpaper/data/database.dart';
import 'package:wallpaper/data/models/image_model.dart';
import 'package:wallpaper/screens/image_detail.dart';

class RecentPage extends StatefulWidget {
  final Stream clearStream;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const RecentPage({Key key, this.clearStream, this.scaffoldKey})
      : super(key: key);

  @override
  _RecentPageState createState() => new _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  static final dateFormatYMdHms = DateFormat.yMd().add_Hms();
  static final dateFormatYMd = DateFormat.yMd();
  final imageDb = new ImageDb.getInstance();
  List<ImageModel> _image;

  @override
  void initState() {
    super.initState();
    widget.clearStream.asyncMap((_) => imageDb.deleteAll()).listen(_onData);
    imageDb.getImages().then((v) => setState(() => _image = v));
  }

  @override
  void dispose() {
    debugPrint(':H: dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(':H: build');
    if (_image == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    final list = groupByDay(_image);
    debugPrint(list.toString());

    return new ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        final item = list[index];
        final images = item['images'] as List;

        return new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new ListTile(title: Text(dateFormatYMd.format(item['date']))),
            new Column(
              children: images.map<Widget>((m) {
                return _buildItem(m['image'], m['index']);
              }).toList(),
              mainAxisSize: MainAxisSize.min,
            )
          ],
        );
      },
      itemCount: list.length,
    );
  }

  List groupByDay(List<ImageModel> images) {
    final map = <DateTime, List<Map>>{};
    images.asMap().forEach((index, img) {
      final viewTime = img.viewTime;
      final day = new DateTime(viewTime.year, viewTime.month, viewTime.day);
      map[day] ??= <Map>[];
      map[day].add({
        'image': img,
        'index': index,
      });
    });
    final list = [];
    map.forEach((k, v) {
      list.add({
        'date': k,
        'images': v,
      });
    });
    return list;
  }

  Widget _buildItem(ImageModel image, int index) {
    return new Dismissible(
      background: new Container(
        child: new Padding(
          padding: const EdgeInsets.all(16.0),
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Text(
                'Delete',
                style: Theme
                    .of(context)
                    .textTheme
                    .subhead,
              ),
              SizedBox(width: 16.0),
              Icon(
                Icons.delete_sweep,
                size: 32.0,
              ),
            ],
          ),
        ),
      ),
      key: Key(image.id),
      onDismissed: (_) => _remove(image.id, index),
      child: new GestureDetector(
        onTap: () => _onTap(image),
        child: new Card(
          elevation: 3.0,
          shape: new RoundedRectangleBorder(
            borderRadius: new BorderRadius.all(
              new Radius.circular(4.0),
            ),
          ),
          color: Theme
              .of(context)
              .backgroundColor,
          child: new Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: new FadeInImage.assetNetwork(
                image: image.thumbnailUrl,
                placeholder: '',
              ),
              title: Text(
                image.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(dateFormatYMdHms.format(image.viewTime)),
              trailing: IconButton(
                icon: Icon(Icons.close),
                tooltip: 'Remove history',
                onPressed: () => _remove(image.id, index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onData(int event) {
    setState(() => _image = []);
    widget.scaffoldKey.currentState.showSnackBar(
      new SnackBar(content: new Text('Delete successfully')),
    );
  }

  _remove(String id, int index) {
    imageDb.delete(id).then((i) {
      if (i > 0) {
        widget.scaffoldKey.currentState.showSnackBar(
          new SnackBar(content: new Text('Delete successfully')),
        );

        _image.removeAt(index);
        setState(() {});
      } else {
        widget.scaffoldKey.currentState.showSnackBar(
          new SnackBar(content: new Text('Delete failed')),
        );
      }
    }).catchError(
          (e) =>
          widget.scaffoldKey.currentState.showSnackBar(
            new SnackBar(content: new Text('Delete error: $e')),
          ),
    );
  }

  _onTap(ImageModel image) async {
    final route = new MaterialPageRoute(
      builder: (context) => new ImageDetailPage(image),
    );
    await Navigator.push(context, route);
    imageDb.getImages().then((v) => setState(() => _image = v));
  }
}
