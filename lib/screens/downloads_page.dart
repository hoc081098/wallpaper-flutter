import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallpaper/data/database.dart';
import 'package:wallpaper/data/models/downloaded_image.dart';

class DownloadedPage extends StatefulWidget {
  @override
  _DownloadedPageState createState() => _DownloadedPageState();
}

class _DownloadedPageState extends State<DownloadedPage> {
  static final dateFormatYMdHms = DateFormat.yMd().add_Hms();
  _DownloadedBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = _DownloadedBloc();
    bloc.fetch();
  }

  @override
  void dispose() {
    bloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).backgroundColor,
      child: StreamBuilder<List<_ListItem>>(
          stream: bloc.listItems$,
          initialData: bloc.listItems$.value,
          builder: (context, snapshot) {
            final data = snapshot.data;

            if (data == null) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }

            return ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                if (item is _ImageItem) {
                  final image = item.image;

                  return ListTile(
                    leading: CachedNetworkImage(
                      imageUrl: image.imageUrl,
                      fit: BoxFit.cover,
                    ),
                    title: Text(
                      image.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Downloaded at: ${dateFormatYMdHms.format(image.createdAt)}',
                      textScaleFactor: 0.8,
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.close),
                      tooltip: 'Delete',
                      onPressed: () {},
                    ),
                  );
                }
              },
            );
          }),
    );
  }
}

///
/// BLoC
///

abstract class _ListItem {}

class _ImageItem implements _ListItem {
  final DownloadedImage image;

  _ImageItem(this.image);
}

class _HeaderItem implements _ListItem {
  final String date;

  _HeaderItem(this.date);
}

class _DownloadedBloc {
  final void Function() fetch;

  final ValueObservable<List<_ListItem>> listItems$;

  final void Function() dispose;

  _DownloadedBloc._(
    this.fetch,
    this.listItems$,
    this.dispose,
  );

  factory _DownloadedBloc() {
    final fetchS = PublishSubject<void>();

    final listItems$ = fetchS
        .switchMap((_) async* {
          yield await ImageDB.getInstance().getDownloadedImages();
        })
        .map(_groupByDate)
        .publishValueSeeded(null);

    final connect = listItems$.connect();

    return _DownloadedBloc._(
      () => fetchS.add(null),
      listItems$,
      () {
        fetchS.close();
        connect.cancel();
      },
    );
  }

  static List<_ListItem> _groupByDate(List<DownloadedImage> images) {
    return [for (final image in images) _ImageItem(image)];
  }
}
