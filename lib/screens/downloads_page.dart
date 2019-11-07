import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';
import 'package:wallpaper/data/database.dart';
import 'package:wallpaper/data/models/downloaded_image.dart';
import 'package:wallpaper/screens/downloaded_image_detail_page.dart';

class DownloadedPage extends StatefulWidget {
  @override
  _DownloadedPageState createState() => _DownloadedPageState();
}

class _DownloadedPageState extends State<DownloadedPage> {
  static final dateFormatYMdHms = DateFormat.yMd().add_Hms();
  static final dateFormatYMd = DateFormat.yMd();

  _DownloadedBloc bloc;
  StreamSubscription subscription;

  @override
  void initState() {
    super.initState();
    bloc = _DownloadedBloc();
    subscription = bloc.event$.listen(_handleEvent);
    bloc.fetch();
  }

  @override
  void dispose() {
    subscription.cancel();
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

            if (data.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    'Your downloaded images is empty',
                    style: Theme.of(context).textTheme.title,
                  ),
                ),
                color: Theme.of(context).backgroundColor,
              );
            }

            return ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];

                if (item is _HeaderItem) {
                  final now = DateTime.now();
                  final date = item.date;

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
                  return ListTile(
                    leading: Image.file(
                      item.imageFile,
                      fit: BoxFit.cover,
                    ),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Downloaded at: ${dateFormatYMdHms.format(item.createdAt)}',
                      textScaleFactor: 0.8,
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.close),
                      tooltip: 'Delete',
                      onPressed: () => showAlertDeleteImage(item),
                    ),
                    onTap: () async {
                      final shouldReload = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DownloadedImageDetailPage(
                            imageDetail: ImageDetail(
                              id: item.id,
                              name: item.name,
                              imageFile: item.imageFile,
                              createdAt: item.createdAt,
                            ),
                          ),
                        ),
                      );

                      if (shouldReload == true) {
                        bloc.fetch();
                      }
                    },
                  );
                }

                return Container(width: 0, height: 0);
              },
            );
          }),
    );
  }

  void showAlertDeleteImage(_ImageItem item) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete'),
          content: Text('Delete image. This action cannot be undone!'),
          actions: <Widget>[
            FlatButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            FlatButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
    if (delete ?? false) {
      bloc.delete(item);
    }
  }

  void _handleEvent(_Event event) {
    if (event is DeletedImage) {
      _showSnackBar('Deleted ${event.item.name} successfully');
    }
    if (event is DeleteImageError) {
      _showSnackBar('Error when deleting ${event.item.name}');
    }
  }

  _showSnackBar(String message) =>
      Scaffold.of(context).showSnackBar(SnackBar(content: Text(message)));
}

///
/// BLoC
///

abstract class _ListItem {}

class _ImageItem implements _ListItem {
  final String id;
  final String name;
  final File imageFile;
  final DateTime createdAt;

  _ImageItem({
    @required this.id,
    @required this.name,
    @required this.imageFile,
    @required this.createdAt,
  });
}

class _HeaderItem implements _ListItem {
  final DateTime date;

  _HeaderItem(this.date);
}

abstract class _Event {}

class DeletedImage implements _Event {
  final _ImageItem item;

  DeletedImage(this.item);
}

class DeleteImageError implements _Event {
  final _ImageItem item;
  final error;

  DeleteImageError(this.item, this.error);
}

class _DownloadedBloc {
  final void Function() fetch;
  final void Function(_ImageItem item) delete;

  final ValueObservable<List<_ListItem>> listItems$;
  final Stream<_Event> event$;

  final void Function() dispose;

  _DownloadedBloc._(
    this.fetch,
    this.delete,
    this.listItems$,
    this.event$,
    this.dispose,
  );

  factory _DownloadedBloc() {
    // ignore_for_file: close_sinks
    final fetchS = PublishSubject<void>();
    final deleteImageS = PublishSubject<_ImageItem>();

    ///
    ///
    ///
    Directory _cachedStorageDir;
    getStorageDir() async {
      if (_cachedStorageDir != null) {
        return _cachedStorageDir;
      }
      if (Platform.isAndroid) {
        _cachedStorageDir = await getExternalStorageDirectory();
        return _cachedStorageDir;
      }
      if (Platform.isIOS) {
        _cachedStorageDir = await getApplicationDocumentsDirectory();
        return _cachedStorageDir;
      }
      throw StateError('Not yet support ${Platform.operatingSystem}');
    }

    ///
    ///
    ///
    final listItems$ = fetchS
        .switchMap((_) async* {
          final images = await ImageDB.getInstance().getDownloadedImages();
          final storageDirectory = await getStorageDir();
          yield Tuple2(images, storageDirectory);
        })
        .map(_groupByDate)
        .publishValueSeeded(null);

    final event$ = deleteImageS.groupBy((item) => item.id).flatMap((group$) {
      return group$.throttleTime(const Duration(milliseconds: 500)).exhaustMap(
        (item) async* {
          try {
            await item.imageFile.delete();
            await ImageDB.getInstance().deleteDownloadedImageById(id: item.id);
            yield DeletedImage(item);
            fetchS.add(null);
          } catch (e) {
            yield DeleteImageError(item, e);
          }
        },
      );
    }).publish();

    final subscriptions = [
      listItems$.connect(),
      event$.connect(),
    ];

    ///
    ///
    ///
    return _DownloadedBloc._(
      () => fetchS.add(null),
      deleteImageS.add,
      listItems$,
      event$,
      () {
        [fetchS, deleteImageS].forEach((s) => s.close());
        subscriptions.forEach((s) => s.cancel());
      },
    );
  }

  static List<_ListItem> _groupByDate(
    Tuple2<List<DownloadedImage>, Directory> tuple,
  ) {
    final items = <_ListItem>[];

    final images = tuple.item1;
    final directory = tuple.item2;

    DateTime prev;
    for (final image in images) {
      final createdAt = image.createdAt;
      if (prev == null ||
          (prev.year != createdAt.year ||
              prev.month != createdAt.month ||
              prev.day != createdAt.day)) {
        final createdAtTrimHms = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
        );

        items.add(_HeaderItem(createdAtTrimHms));

        prev = createdAtTrimHms;
      }

      items.add(
        _ImageItem(
          id: image.id,
          imageFile: File(path.join(directory.path, image.imageUrl)),
          createdAt: createdAt,
          name: image.name,
        ),
      );
    }

    return items;
  }
}
