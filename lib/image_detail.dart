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
  StreamSubscription<DocumentSnapshot> subscription;
  bool isLoading;
  final scaffoldKey = new GlobalKey<ScaffoldState>();
  static const methodChannel = MethodChannel(channel);

  @override
  void initState() {
    super.initState();
    isLoading = false;
    imageModel = widget.imageModel;
    subscription = imagesCollection
        .document(imageModel.id)
        .snapshots()
        .listen((DocumentSnapshot documentSnapshot) {
      final newImageModel = new ImageModel.fromJson(
        id: documentSnapshot.documentID,
        json: documentSnapshot.data,
      );
      setState(() => imageModel = newImageModel);
    });
  }

  @override
  void dispose() {
    subscription.cancel();
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
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
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
          ],
        ),
        height: kToolbarHeight + MediaQuery.of(context).padding.top,
        padding: new EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        constraints: new BoxConstraints.expand(
            height: kToolbarHeight + MediaQuery.of(context).padding.top),
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
          placeholder: new Image.asset('picture.png'),
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

  FloatingActionButton _buildFloatingActionButton() {
    return new FloatingActionButton.extended(
      onPressed: isLoading ? null : _downloadImage,
      tooltip: 'Donwload and set wallpaper',
      icon: new Icon(isLoading ? Icons.wallpaper : Icons.arrow_downward),
      label: Text('Donwload'),
    );
  }

  _showSnackBar(String text,
      {Duration duration = const Duration(seconds: 1, milliseconds: 500)}) {
    return scaffoldKey.currentState.showSnackBar(
        new SnackBar(content: new Text(text), duration: duration));
  }

  Future<Null> _downloadImage() async {
    try {
      setState(() => isLoading = true);

      // get external directory
      final externalDir = await getExternalStorageDirectory();

      // check if 'flutterImages' in externalDir is exists
      // if not exists, check and request runtime permission, then create this directory
      // else nothing
      final dir = new Directory(path.join(externalDir.path, 'flutterImages'));
      if (!(await dir.exists())) {
        final check = await SimplePermissions
            .checkPermission(Permission.WriteExternalStorage);
        if (!check) {
          _showSnackBar('Permission denined');
          final requestRes = await SimplePermissions
              .requestPermission(Permission.WriteExternalStorage);
          if (!requestRes) {
            _showSnackBar('Permission denined. Go to setting to granted!');
            return _done();
          }
        }

        await dir.create();
      }

      // check file is exists, if exists not download again
      var filePath =
          path.join(externalDir.path, 'flutterImages', imageModel.id + '.png');
      final file = new File(filePath);
      if (await file.exists()) {
        if (await file.length() > 0) {
          _showSnackBar('Already download this image!');
        } else {
          await file.delete();
        }
      } else {
        final List<int> bytes = await http.readBytes(imageModel.imageUrl);
        final queryData = MediaQuery.of(context);
        final res = await compute<Map<String, dynamic>, bool>(
          resizeAndSaveImage,
          <String, dynamic>{
            'width': (queryData.size.shortestSide * queryData.devicePixelRatio)
                .toInt(),
            'height': (queryData.size.longestSide * queryData.devicePixelRatio)
                .toInt(),
            'filePath': filePath,
            'bytes': bytes,
          },
        );
        if (!res) {
          _showSnackBar("Failed to download image");
          return _done();
        }
      }

      // set image as wallpaper ?
      final agree = await _showDialogSetImageAsWallpaper();
      if (agree) {
        final String res = await methodChannel.invokeMethod(
          setWallpaper,
          ['flutterImages', '${imageModel.id}.png'],
        );
        _showSnackBar(res);
      }
    } on PlatformException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar("Error: $e");
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
            content: new Text('Do you want set this image as wallpaper?'),
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
}

bool resizeAndSaveImage(Map<String, dynamic> map) {
  try {
    final image = img.decodeImage(map['bytes']);
    final copyImage = img.copyResize(image, map['width'], map['height']);
    new File(map['filePath'])
      ..createSync()
      ..writeAsBytesSync(img.encodePng(copyImage));
    return true;
  } catch (e) {
    return false;
  }
}
