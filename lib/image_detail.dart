import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:simple_permissions/simple_permissions.dart';
import 'package:wallpaper/category_page.dart';
import 'package:wallpaper/database.dart';
import 'package:wallpaper/main.dart';
import 'package:wallpaper/models.dart';
import 'package:zoomable_image/zoomable_image.dart';

class ImageDetailPage extends StatefulWidget {
  final ImageModel imageModel;

  const ImageDetailPage(this.imageModel, {Key key}) : super(key: key);

  @override
  _ImageDetailPageState createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends State<ImageDetailPage> {
  ImageModel imageModel;
  final imagesCollection = Firestore.instance.collection('images');
  StreamSubscription subscription;
  bool isLoading;
  final scaffoldKey = new GlobalKey<ScaffoldState>();
  static const methodChannel = MethodChannel(channel);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    isLoading = false;
    imageModel = widget.imageModel;
    subscription = imagesCollection
        .document(imageModel.id)
        .snapshots()
        .map(mapperImageModel)
        .listen((ImageModel newImage) => setState(() => imageModel = newImage));
    _increaseCount('viewCount', imageModel.id);
    _insertToRecent(imageModel);
  }

  @override
  void dispose() {
    subscription.cancel();
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      key: scaffoldKey,
      body: new Container(
        decoration: _buildBoxDecoration(),
        child: new Stack(
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
    return new Positioned(
      child: new Container(
        child: new Row(
          children: <Widget>[
            _buildCloseIcon(context),
            new SizedBox(width: 8.0),
            _buildImageNameText(),
            new IconButton(
              icon: Icon(Icons.share),
              onPressed: _shareImageToFacebook,
            ),
          ],
        ),
        height: kToolbarHeight,
        constraints: new BoxConstraints.expand(height: kToolbarHeight),
        decoration: new BoxDecoration(
          gradient: new LinearGradient(
              colors: <Color>[
                Colors.black,
                Colors.black.withOpacity(0.2),
              ],
              begin: AlignmentDirectional.topCenter,
              end: AlignmentDirectional.bottomCenter,
              stops: [0.0, 0.9]),
        ),
      ),
      top: 0.0,
      left: 0.0,
      right: 0.0,
    );
  }

  Expanded _buildImageNameText() {
    return new Expanded(
      child: new Text(
        imageModel.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: new TextStyle(color: Colors.white, fontSize: 16.0),
      ),
    );
  }

  ClipOval _buildCloseIcon(BuildContext context) {
    return new ClipOval(
      child: new Container(
        color: Colors.black.withOpacity(0.3),
        child: new IconButton(
          icon: new Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Center _buildCenterImage() {
    return new Center(
      child: new Hero(
        tag: imageModel.id,
        child: new ZoomableImage(
          new NetworkImage(imageModel.imageUrl),
          placeholder: new Image.asset('assets/picture.png'),
          backgroundColor: Colors.black.withOpacity(0.8),
        ),
      ),
    );
  }

  BoxDecoration _buildBoxDecoration() {
    return new BoxDecoration(
      gradient: new LinearGradient(
        colors: <Color>[
          Colors.black.withOpacity(0.8),
          Colors.black.withOpacity(0.9),
        ],
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      ),
    );
  }

  _shareImageToFacebook() {
    final url = imageModel.imageUrl;
    methodChannel.invokeMethod(shareImageToFacebook, url);
  }

  _showSnackBar(String text,
      {Duration duration = const Duration(seconds: 1, milliseconds: 500)}) {
    return scaffoldKey.currentState.showSnackBar(
        new SnackBar(content: new Text(text), duration: duration));
  }

  Future _downloadImage() async {
    try {
      setState(() => isLoading = true);

      // get external directory
      final externalDir = await getExternalStorageDirectory();

      // request runtime permission
      if (!(await SimplePermissions
          .checkPermission(Permission.WriteExternalStorage))) {
        final requestRes = await SimplePermissions
            .requestPermission(Permission.WriteExternalStorage);
        if (!requestRes) {
          _showSnackBar('Permission denined. Go to setting to granted!');
          return _done();
        }
      }

      // check file is exists, if exists then delete file
      final filePath =
          path.join(externalDir.path, 'flutterImages', imageModel.id + '.png');
      final file = new File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // increase download count
      _increaseCount('downloadCount', imageModel.id);

      // after that, download and resize image
      final List<int> bytes = await http.readBytes(imageModel.imageUrl);
      final queryData = MediaQuery.of(context);
      final res = await compute<Map<String, dynamic>, bool>(
        resizeAndSaveImage,
        <String, dynamic>{
          'width': (queryData.size.shortestSide * queryData.devicePixelRatio)
              .toInt(),
          'height':
              (queryData.size.longestSide * queryData.devicePixelRatio).toInt(),
          'filePath': filePath,
          'bytes': bytes,
        },
      );

      // call scanFile method
      methodChannel.invokeMethod(
        scanFile,
        <String>['flutterImages', '${imageModel.id}.png'],
      ).then((scanFileRes) => debugPrint("Scan file: $scanFileRes"));

      _showSnackBar(
        res ? 'Image downloaded successfully' : 'Failed to download image',
      );
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
          return new AlertDialog(
            title: Text('Set wallpaper'),
            content: new Text('Set this image as wallpaper?'),
            actions: <Widget>[
              new FlatButton(
                child: new Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              new FlatButton(
                onPressed: () => Navigator.pop(context, true),
                child: new Text('Yes'),
              ),
            ],
          );
        });
  }

  Widget _buildButtons() {
    final onPressedWhileLoading =
        () => _showSnackBar("Downloading...Please wait");
    return new Positioned(
      child: new Column(
        children: <Widget>[
          new Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child:
                isLoading ? new CircularProgressIndicator() : new Container(),
          ),
          new Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              new Flexible(
                child: new FlatButton(
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
              new Flexible(
                child: new FlatButton(
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
      if (!(await new File(filePath).exists())) {
        return _showSnackBar('You need donwload image before');
      }

      // set image as wallpaper
      if (await _showDialogSetImageAsWallpaper()) {
        final String res = await methodChannel.invokeMethod(
          setWallpaper,
          ['flutterImages', '${imageModel.id}.png'],
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
    new ImageDb.getInstance()
        .insert(image)
        .then((i) => debugPrint("Inserted $i"))
        .catchError((e) => debugPrint("Inserted error $e"));
  }
}

bool resizeAndSaveImage(Map<String, dynamic> map) {
  try {
    final image = img.decodeImage(map['bytes']);
    final copyImage = img.copyResize(image, map['width'], map['height']);
    new File(map['filePath'])
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(copyImage));
    return true;
  } catch (e) {
    return false;
  }
}
