import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pedantic/pedantic.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallpaper/constants.dart';
import 'package:wallpaper/data/database.dart';
import 'package:wallpaper/data/models/downloaded_image.dart';
import 'package:wallpaper/data/models/image_model.dart';
import 'package:wallpaper/utils.dart';

class ImageDetailPage extends StatefulWidget {
  final ImageModel imageModel;

  const ImageDetailPage(this.imageModel, {Key key}) : super(key: key);

  @override
  _ImageDetailPageState createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends State<ImageDetailPage> {
  final imagesCollection = Firestore.instance.collection('images');
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final imageDB = ImageDB.getInstance();

  StreamSubscription subscription;
  StreamSubscription subscription1;
  ImageModel imageModel;
  bool isLoading;

  final StreamController<bool> _isFavoriteStreamController =
      StreamController.broadcast();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);

    isLoading = false;
    imageModel = widget.imageModel;

    final imageStream = imagesCollection
        .document(imageModel.id)
        .snapshots()
        .map(mapperImageModel);
    subscription = imageStream.listen(_onListen);

    _increaseCount('viewCount', imageModel.id);
    _insertToRecent(imageModel);

    subscription1 = Rx.combineLatest2<ImageModel, bool, Map<String, dynamic>>(
      imageStream,
      _isFavoriteStreamController.stream.distinct(),
      (img, isFav) => {
        'image': img,
        'isFavorite': isFav,
      },
    )
        .where((map) => map['isFavorite'])
        .map<ImageModel>((map) => map['image'])
        .listen((ImageModel newImage) {
      debugPrint('onListen fav $newImage');
      debugPrint('onListen fav old $imageModel');

      imageDB
          .updateFavoriteImage(newImage)
          .then((i) => debugPrint('Updated fav $i'))
          .catchError((e) => debugPrint('Updated fav error $e'));
    });

    _isFavoriteStreamController.addStream(
      Stream.fromFuture(
        imageDB.isFavoriteImage(imageModel.id),
      ),
    );
  }

  @override
  void dispose() {
    subscription.cancel();
    subscription1.cancel();
    _isFavoriteStreamController.close();
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        key: scaffoldKey,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Theme.of(context).backgroundColor.withOpacity(0.8),
                Theme.of(context).backgroundColor.withOpacity(0.9),
              ],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
          ),
          child: Stack(
            children: <Widget>[
              _buildCenterImage(),
              _buildAppbar(context),
              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Positioned _buildAppbar(BuildContext context) {
    final favoriteIconButton = StreamBuilder(
      stream: _isFavoriteStreamController.stream.distinct(),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        debugPrint('DEBUG ${snapshot.data}');

        if (snapshot.hasError || !snapshot.hasData) {
          return Container();
        }
        final isFavorite = snapshot.data;
        return IconButton(
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          onPressed: () => _changeFavoriteStatus(isFavorite),
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
        );
      },
    );

    final closeButton = ClipOval(
      child: Container(
        color: Colors.black.withOpacity(0.2),
        child: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );

    final textName = Expanded(
      child: Text(
        imageModel.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white, fontSize: 16.0),
      ),
    );

    return Positioned(
      child: Container(
        child: Row(
          children: <Widget>[
            closeButton,
            SizedBox(width: 8.0),
            textName,
            favoriteIconButton,
            IconButton(
              icon: Icon(Icons.share),
              onPressed: _shareImageToFacebook,
              tooltip: 'Share to facebook',
            ),
          ],
        ),
        height: kToolbarHeight,
        constraints: BoxConstraints.expand(height: kToolbarHeight),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Colors.black,
              Colors.transparent,
            ],
            begin: AlignmentDirectional.topCenter,
            end: AlignmentDirectional.bottomCenter,
            stops: const [0.1, 0.9],
          ),
        ),
      ),
      top: 0.0,
      left: 0.0,
      right: 0.0,
    );
  }

  Center _buildCenterImage() {
    return Center(
      child: Hero(
        tag: imageModel.id,
        child: CachedNetworkImage(
          imageUrl: imageModel.imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            constraints: BoxConstraints.expand(),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Image.asset(
                    'assets/picture.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shareImageToFacebook() async {
    showProgressDialog(context, 'Loading...');
    try {
      await methodChannel.invokeMethod(
        shareImageToFacebook,
        imageModel.imageUrl,
      );
    } catch (e) {
      print('Share to fb error: $e');
    } finally {
      print('Share to fb done');
      Navigator.pop(context);
    }
  }

  void _showSnackBar(String text,
      {Duration duration = const Duration(seconds: 1)}) {
    scaffoldKey.currentState
        ?.showSnackBar(SnackBar(content: Text(text), duration: duration));
  }

  Future _downloadImage() async {
    try {
      setState(() => isLoading = true);

      final targetPlatform = Theme.of(context).platform;

      if (targetPlatform == TargetPlatform.android) {
        // request runtime permission
        if (!(await Permission.storage.isGranted)) {
          if (!(await Permission.storage.request().isGranted)) {
            _showSnackBar(
                'Permission denied. Go to setting to granted storage permission!');
            return _done();
          }
        }
      }

      // get external directory
      Directory externalDir;
      switch (targetPlatform) {
        case TargetPlatform.android:
          externalDir = await getExternalStorageDirectory();
          break;
        case TargetPlatform.iOS:
          externalDir = await getApplicationDocumentsDirectory();
          break;
        default:
          _showSnackBar('Not support target: $targetPlatform');
          return _done();
      }
      print('externalDir=$externalDir');

      final filePath =
          path.join(externalDir.path, 'flutterImages', imageModel.id + '.png');

      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }

      print('Start download...');
      final bytes = await http.readBytes(imageModel.imageUrl);
      print('Done download...');

      final queryData = MediaQuery.of(context);
      final width =
          (queryData.size.shortestSide * queryData.devicePixelRatio).toInt();
      final height =
          (queryData.size.longestSide * queryData.devicePixelRatio).toInt();

      final outBytes = await methodChannel.invokeMethod(
        resizeImage,
        <String, dynamic>{
          'bytes': bytes,
          'width': width,
          'height': height,
        },
      );

      //save image to storage
      final saveFileResult =
          saveImage({'filePath': filePath, 'bytes': outBytes});

      if (saveFileResult) {
        await ImageDB.getInstance().insertDownloadedImage(
          DownloadedImage(
            imageModel.id,
            imageModel.name,
            path.join('flutterImages', imageModel.id + '.png'),
            DateTime.now(),
          ),
        );
      }

      _showSnackBar(
        saveFileResult
            ? 'Image downloaded successfully'
            : 'Failed to download image',
      );

      // call scanFile method, to show image in gallery
      unawaited(
        methodChannel
            .invokeMethod(
              scanFile,
              <String>['flutterImages', '${imageModel.id}.png'],
            )
            .then((result) => print('Scan file: $result'))
            .catchError((e) => print('Scan file error: $e')),
      );

      // increase download count
      _increaseCount('downloadCount', imageModel.id);
    } on PlatformException catch (e) {
      _showSnackBar(e.message);
    } catch (e, s) {
      _showSnackBar('An error occurred');
      debugPrint('Download image: $e, $s');
    }

    return _done();
  }

  void _done() {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<bool> _showDialogSetImageAsWallpaper() {
    return showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Set wallpaper'),
            content: Text('Set this image as wallpaper?'),
            actions: <Widget>[
              FlatButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              FlatButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Yes'),
              ),
            ],
          );
        });
  }

  Widget _buildButtons() {
    final onPressedWhileLoading =
        () => _showSnackBar('Downloading...Please wait');
    return Positioned(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: isLoading ? CircularProgressIndicator() : Container(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: FlatButton(
                  padding: const EdgeInsets.all(16.0),
                  onPressed: isLoading ? onPressedWhileLoading : _downloadImage,
                  child: Text(
                    'Download',
                    textAlign: TextAlign.center,
                  ),
                  color: Colors.black.withOpacity(0.7),
                ),
                fit: FlexFit.tight,
              ),
              Flexible(
                child: FlatButton(
                  padding: const EdgeInsets.all(16.0),
                  onPressed: isLoading ? onPressedWhileLoading : _setWallpaper,
                  child: Text(
                    'Set wallpaper',
                    textAlign: TextAlign.center,
                  ),
                  color: Colors.black.withOpacity(0.7),
                ),
                fit: FlexFit.tight,
              ),
            ],
          ),
        ],
      ),
      left: 0.0,
      right: 0.0,
      bottom: 0.0,
    );
  }

  Future<void> _setWallpaper() async {
    try {
      final targetPlatform = Theme.of(context).platform;

      // get external directory
      Directory externalDir;
      switch (targetPlatform) {
        case TargetPlatform.android:
          externalDir = await getExternalStorageDirectory();
          break;
        case TargetPlatform.iOS:
          externalDir = await getApplicationDocumentsDirectory();
          break;
        default:
          _showSnackBar('Not support target: $targetPlatform');
          return _done();
      }
      final filePath =
          path.join(externalDir.path, 'flutterImages', imageModel.id + '.png');

      // check image is exists
      if (!File(filePath).existsSync()) {
        return _showSnackBar('You need donwload image before');
      }

      if (targetPlatform == TargetPlatform.android) {
        // set image as wallpaper
        if (await _showDialogSetImageAsWallpaper()) {
          showProgressDialog(context, 'Please wait...');
          try {
            final res = await methodChannel.invokeMethod(
              setWallpaper,
              <String>['flutterImages', '${imageModel.id}.png'],
            );
            _showSnackBar(res);
          } finally {
            Navigator.pop(context);
          }
        }
      } else if (targetPlatform == TargetPlatform.iOS) {
        await methodChannel.invokeMethod(
          setWallpaper,
          <String>['flutterImages', '${imageModel.id}.png'],
        );
      }
    } on PlatformException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('An error occurred');
      debugPrint('Set wallpaper: $e');
    }
  }

  void _increaseCount(String field, String id) {
    Firestore.instance.runTransaction((transaction) async {
      final document = imagesCollection.document(id);
      final documentSnapshot = await transaction.get(document);
      await transaction.update(document, <String, dynamic>{
        field: 1 + (documentSnapshot.data[field] ?? 0),
      });
    }, timeout: Duration(seconds: 10));
  }

  void _insertToRecent(ImageModel image) {
    imageDB
        .insertRecentImage(image)
        .then((i) => debugPrint('Inserted $i'))
        .catchError((e) => debugPrint('Inserted error $e'));
  }

  void _onListen(ImageModel newImage) {
    debugPrint('onListen $newImage');
    debugPrint('onListen old $imageModel');
    imageDB
        .updateRecentImage(newImage..viewTime = imageModel.viewTime)
        .then((i) => debugPrint('Updated recent $i'))
        .catchError((e) => debugPrint('Updated recent error $e'));
    setState(() => imageModel = newImage);
  }

  void _changeFavoriteStatus(bool isFavorite) {
    final result = isFavorite
        ? imageDB.deleteFavoriteImageById(imageModel.id).then((i) => i > 0)
        : imageDB.insertFavoriteImage(imageModel).then((i) => i != -1);
    result.then((b) {
      final msg = isFavorite ? 'Remove from favorites' : 'Add to favorites';
      if (b) {
        _showSnackBar('$msg successfully');
        _isFavoriteStreamController.add(!isFavorite);
      } else {
        _showSnackBar('$msg unsuccessfully');
      }
      _isFavoriteStreamController.addStream(
        Stream.fromFuture(
          imageDB.isFavoriteImage(imageModel.id),
        ),
      );
    }).catchError((e) {
      debugPrint('DEBUG $e');
      _showSnackBar(e.toString());
    });
  }
}
