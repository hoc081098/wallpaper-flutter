import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:wallpaper/constants.dart';
import 'package:wallpaper/data/models/image_category_model.dart';

class UploadPage extends StatefulWidget {
  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  File _imageFile;
  List<ImageCategory> _imageCategories;
  ImageCategory _selectedCategory;
  StreamSubscription<List<ImageCategory>> subscription;
  TextEditingController _textController = TextEditingController();

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final imagesCollection = Firestore.instance.collection('images');
  final categoriesCollection = Firestore.instance.collection('categories');
  final firebaseStorage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _imageCategories = <ImageCategory>[];
    subscription = categoriesCollection
        .snapshots()
        .map((querySnapshot) => querySnapshot.documents
            .map((doc) =>
                ImageCategory.fromJson(id: doc.documentID, json: doc.data))
            .toList())
        .listen((list) => setState(() => _imageCategories = list));
  }

  @override
  void dispose() {
    super.dispose();
    subscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      body: Container(
        child: Column(
          children: <Widget>[
            _buildImagePreview(),
            _buildCategoryDropDownButton(),
            _buildTextFieldName(),
            _buildButtons(),
          ],
        ),
        color: Theme.of(context).backgroundColor,
      ),
    );
  }

  Widget _buildImagePreview() {
    var placeholder = Stack(
      children: <Widget>[
        Container(
          constraints: BoxConstraints.expand(),
          child: Image.asset(
            'assets/drawer_header_image.jpg',
            fit: BoxFit.cover,
            colorBlendMode: BlendMode.darken,
            color: Colors.black38,
          ),
        ),
        Align(
          child: Text(
            'No selected image',
            textScaleFactor: 1.2,
            style: TextStyle(
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
    return Flexible(
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8.0,
          right: 8.0,
        ),
        child: Material(
          shadowColor: Theme.of(context).accentColor,
          type: MaterialType.card,
          borderRadius: BorderRadius.all(Radius.circular(6.0)),
          elevation: 4.0,
          child: _imageFile == null
              ? placeholder
              : Image.file(
                  _imageFile,
                  fit: BoxFit.cover,
                ),
        ),
      ),
      fit: FlexFit.tight,
    );
  }

  Widget _buildCategoryDropDownButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _imageCategories.isEmpty
              ? Text("Loading categories...")
              : DropdownButton<ImageCategory>(
                  items: _imageCategories.map((c) {
                    return DropdownMenuItem<ImageCategory>(
                        child: Text(c.name), value: c);
                  }).toList(),
                  onChanged: (c) => setState(() => _selectedCategory = c),
                  hint: Text('Select category'),
                  value: _selectedCategory,
                ),
          IconButton(
            tooltip: 'Add category',
            icon: Icon(Icons.add),
            onPressed: _showDialogAddCategory,
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldName() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _textController,
        decoration: InputDecoration(
          labelText: 'Image name',
          filled: true,
          contentPadding: const EdgeInsets.all(8.0),
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _buildButtons() {
    var color = Theme.of(context).primaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: FlatButton(
            padding: const EdgeInsets.all(20.0),
            onPressed: _chooseImage,
            child: Text(
              'Choose image',
              textAlign: TextAlign.center,
            ),
            color: color,
          ),
          fit: FlexFit.tight,
        ),
        Flexible(
          child: FlatButton(
            padding: const EdgeInsets.all(20.0),
            onPressed: _uploadImage,
            child: Text(
              'Upload',
              textAlign: TextAlign.center,
            ),
            color: color,
          ),
          fit: FlexFit.tight,
        ),
      ],
    );
  }

  _chooseImage() async {
    _imageFile = await ImagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080.0,
      maxHeight: 1920.0,
    );
    _textController.text = path.basename(_imageFile.path);
    setState(() {});
  }

  _showSnackBar(String text,
      {Duration duration = const Duration(seconds: 1, milliseconds: 500)}) {
    return scaffoldKey.currentState
        .showSnackBar(SnackBar(content: Text(text), duration: duration));
  }

  bool _validate() {
    if (_imageFile == null) {
      _showSnackBar('Please select image');
      return false;
    }
    if (_selectedCategory == null) {
      _showSnackBar("Please select category");
      return false;
    }
    if (_textController.text.isEmpty) {
      _showSnackBar('Please provider name');
      return false;
    }
    return true;
  }

  _uploadImage() async {
    if (!_validate()) {
      return;
    }
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(),
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text('Uploading...'),
                  ),
                ],
              ),
            ),
          );
        });

    try {
      //upload file
      final extension = path.extension(_imageFile.path);
      final uploadPath =
          'uploadImages/${Uuid().v1()}${extension.isEmpty ? '.png' : extension}';
      var imageReference = firebaseStorage.ref().child(uploadPath);
      final task1 = imageReference.putFile(_imageFile).onComplete;

      var thumbnailReference =
          firebaseStorage.ref().child('uploadImages/${Uuid().v1()}.png');

      final uploadThumbnail = (thumbnailBytes) {
        return thumbnailReference.putData(thumbnailBytes).onComplete;
      };

      final task2 = _imageFile
          .readAsBytes()
          .then((bytes) => Uint8List.fromList(bytes))
          .then(
            (bytes) => methodChannel.invokeMethod(
              resizeImage,
              <String, dynamic>{
                'bytes': bytes,
                'width': 360,
                'height': 640,
              },
            ),
          )
          .then(uploadThumbnail);

      await Future.wait([task1, task2]);

      final urls = await Future.wait([
        imageReference.getDownloadURL(),
        thumbnailReference.getDownloadURL(),
      ]);

      await imagesCollection.add(<String, dynamic>{
        'name': _textController.text,
        'imageUrl': urls[0].toString(),
        'thumbnailUrl': urls[1].toString(),
        'categoryId': _selectedCategory.id,
        'uploadedTime': DateTime.now(),
        'viewCount': 0,
        'downloadCount': 0,
      });

      Navigator.pop(context); //pop dialog
      _showSnackBar('Image uploaded successfully');
    } on PlatformException catch (e) {
      Navigator.pop(context); //pop dialog
      _showSnackBar(e.message);
    } catch (e) {
      Navigator.pop(context); //pop dialog
      _showSnackBar("An error occurred");
      debugPrint('Error $e}');
    }
  }

  _showDialogAddCategory() => scaffoldKey.currentState?.showBottomSheet(
        (context) => AddCategoryBottomSheet(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.zero,
            bottomRight: Radius.zero,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColorLight,
      );
}

///
///
///

class AddCategoryBottomSheet extends StatefulWidget {
  @override
  _AddCategoryState createState() => _AddCategoryState();
}

class _AddCategoryState extends State<AddCategoryBottomSheet>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final categoriesCollection = Firestore.instance.collection('categories');
  final firebaseStorage = FirebaseStorage.instance;

  String _msg;
  File _imageFile;

  AnimationController _animController;
  Animation<double> _anim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    _anim = Tween(begin: 360.0, end: 48.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Interval(0.1, 1.0, curve: Curves.ease),
      ),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).primaryColorLight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Add category'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildTextField(),
          ),
          _buildImagePreview(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _buildMsgTextOrButtonChooseImage(),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              constraints: BoxConstraints.expand(
                height: 48.0,
                width: _anim.value,
              ),
              child: Material(
                elevation: 4.0,
                shadowColor: Theme.of(context).accentColor,
                borderRadius: BorderRadius.all(
                  Radius.circular(32.0),
                ),
                child: _anim.value > 96.0
                    ? MaterialButton(
                        splashColor: Theme.of(context).accentColor,
                        onPressed: _addCategory,
                        child: Text('Add'),
                      )
                    : Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMsgTextOrButtonChooseImage() => _msg != null
      ? Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(_msg),
        )
      : FlatButton.icon(
          onPressed: _chooseImage,
          icon: Icon(Icons.image),
          label: Text('Choose image'),
        );

  Widget _buildImagePreview() => _imageFile != null
      ? Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.file(
            _imageFile,
            width: 64.0,
            height: 64.0,
            fit: BoxFit.cover,
          ),
        )
      : Container();

  TextField _buildTextField() => TextField(
        controller: _textController,
        decoration: InputDecoration(
          labelText: 'Category name',
        ),
        maxLines: 1,
      );

  _addCategory() async {
    if (!_validate()) return;
    _animController.forward();

    //upload file
    final extension = path.extension(_imageFile.path);
    final uploadPath =
        'uploadImages/${Uuid().v1()}${extension.isEmpty ? '.png' : extension}';

    var imageReference = firebaseStorage.ref().child(uploadPath);

    await _imageFile
        .readAsBytes()
        .then((bytes) => Uint8List.fromList(bytes))
        .then(
          (bytes) => methodChannel.invokeMethod(
            resizeImage,
            <String, dynamic>{
              'bytes': bytes,
              'width': 360,
              'height': 360,
            },
          ),
        )
        .then((bytes) => imageReference.putData(bytes).onComplete);

    await categoriesCollection.add(<String, String>{
      'name': _textController.text,
      'imageUrl': (await imageReference.getDownloadURL()).toString(),
    });
    await _animController.reverse();
    await _showMessage('New category added successfully');
    Navigator.pop(context);
  }

  bool _validate() {
    final textIsEmpty = _textController.text.isEmpty;
    if (_imageFile == null && textIsEmpty) {
      _showMessage('Please select image and provide name');
      return false;
    }
    if (_imageFile == null) {
      _showMessage('Please select image');
      return false;
    }
    if (textIsEmpty) {
      _showMessage('Please provide name');
      return false;
    }
    return true;
  }

  _chooseImage() async {
    _imageFile = await ImagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 720.0,
      maxHeight: 720.0,
    );
    setState(() {});
  }

  _showMessage(String text,
      {Duration duration =
          const Duration(seconds: 1, milliseconds: 500)}) async {
    if (mounted) setState(() => _msg = text);
    await Future.delayed(duration, () {
      if (mounted) setState(() => _msg = null);
    });
  }
}
