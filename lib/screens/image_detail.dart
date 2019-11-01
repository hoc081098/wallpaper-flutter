import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallpaper/constants.dart';
import 'package:wallpaper/data/database.dart';
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

  StreamController<bool> _isFavoriteStreamController =
  StreamController.broadcast();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);

    isLoading = false;
    imageModel = widget.imageModel;

    var imageStream = Observable(imagesCollection
        .document(imageModel.id)
        .snapshots()
        .map(mapperImageModel));
    subscription = imageStream.listen(_onListen);

    _increaseCount('viewCount', imageModel.id);
    _insertToRecent(imageModel);

    subscription1 =
        Observable.combineLatest2<ImageModel, bool, Map<String, dynamic>>(
          imageStream,
          _isFavoriteStreamController.stream.distinct(),
              (img, isFav) =>
          {
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
    return Scaffold(
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

    var closeButton = ClipOval(
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

    var textName = Expanded(
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
            stops: [0.1, 0.9],
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
          placeholder: (context, url) =>
              Container(
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

  _shareImageToFacebook() {
    final url = imageModel.imageUrl;
    methodChannel.invokeMethod(shareImageToFacebook, url);
  }

  _showSnackBar(String text,
      {Duration duration = const Duration(seconds: 1, milliseconds: 500)}) {
    return scaffoldKey.currentState?.showSnackBar(
        SnackBar(content: Text(text), duration: duration));
  }

  Future _downloadImage() async {
    try {
      setState(() => isLoading = true);

      // request runtime permission
      final permissionHandler = PermissionHandler();
      final status = await permissionHandler
          .checkPermissionStatus(PermissionGroup.storage);
      if (status != PermissionStatus.granted) {
        final requestRes = await permissionHandler
            .requestPermissions([PermissionGroup.storage]);
        if (requestRes[PermissionGroup.storage] != PermissionStatus.granted) {
          _showSnackBar('Permission denined. Go to setting to granted!');
          return _done();
        }
      }

      // get external directory
      Directory externalDir;

      switch (Theme
          .of(context)
          .platform) {
        case TargetPlatform.android:
          externalDir = await getExternalStorageDirectory();
          break;
        case TargetPlatform.fuchsia:
          _showSnackBar('Not support fuchsia');
          return _done();
        case TargetPlatform.iOS:
          externalDir = await getApplicationDocumentsDirectory();
          break;
      }

      // check file is exists, if exists then delete file
      final filePath =
          path.join(externalDir.path, 'flutterImages', imageModel.id + '.png');
      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }

      print(file);

      // increase download count
      _increaseCount('downloadCount', imageModel.id);

      // after that, download and resize image
      final Uint8List bytes = await http.readBytes(imageModel.imageUrl);
      // resize image ??
      final queryData = MediaQuery.of(context);
      final Uint8List outBytes = await methodChannel.invokeMethod(
        resizeImage,
        <String, dynamic>{
          'bytes': bytes,
          'width': (queryData.size.shortestSide * queryData.devicePixelRatio)
              .toInt(),
          'height':
              (queryData.size.longestSide * queryData.devicePixelRatio).toInt(),
        },
      );

      //save image to storage
      final message = (await compute<Map<String, dynamic>, bool>(
        saveImage,
        <String, dynamic>{'filePath': filePath, 'bytes': outBytes},
      )) ? 'Image downloaded successfully'
          : 'Failed to download image';

      _showSnackBar(message);

      // call scanFile method, to show image in gallery
      methodChannel.invokeMethod(scanFile, <String>[
        'flutterImages',
        '${imageModel.id}.png'
      ]).then((scanFileRes) => debugPrint("Scan file: $scanFileRes"));

    } on PlatformException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('An error occurred');
      debugPrint("Download image: $e");
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
        () => _showSnackBar("Downloading...Please wait");
    return Positioned(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child:
            isLoading ? CircularProgressIndicator() : Container(),
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

  _setWallpaper() async {
    try {
      // get external directory
      final externalDir = await getExternalStorageDirectory();
      final filePath =
          path.join(externalDir.path, 'flutterImages', imageModel.id + '.png');

      // check image is exists
      if (!(await File(filePath).exists())) {
        return _showSnackBar('You need donwload image before');
      }

      // set image as wallpaper
      if (await _showDialogSetImageAsWallpaper()) {
        final String res = await methodChannel.invokeMethod(
          setWallpaper,
          <String>['flutterImages', '${imageModel.id}.png'],
        );
        _showSnackBar(res);
      }
    } on PlatformException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('An error occurred');
      debugPrint("Set wallpaper: $e");
    }
  }

  _increaseCount(String field, String id) {
    Firestore.instance.runTransaction((transaction) async {
      final document = imagesCollection.document(id);
      final documentSnapshot = await transaction.get(document);
      await transaction.update(document, <String, dynamic>{
        field: 1 + (documentSnapshot.data[field] ?? 0),
      });
    }, timeout: Duration(seconds: 10));
  }

  _insertToRecent(ImageModel image) {
    imageDB
        .insertRecentImage(image)
        .then((i) => debugPrint("Inserted $i"))
        .catchError((e) => debugPrint("Inserted error $e"));
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
    var result = isFavorite
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
