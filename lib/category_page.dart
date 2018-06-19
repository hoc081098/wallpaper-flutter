import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:wallpaper/image_detail.dart';
import 'package:wallpaper/models.dart';

class CategoryPage extends StatelessWidget {
  final imagesCollection = Firestore.instance.collection('categories');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ImageCategory>>(
      stream: categoriesStream,
      builder: _buildCategoryList,
    );
  }

  Stream<List<ImageCategory>> get categoriesStream {
    return imagesCollection
        .orderBy('name')
        .snapshots()
        .map((QuerySnapshot querySnapshot) {
      return querySnapshot.documents.map((DocumentSnapshot documentSnapshot) {
        return new ImageCategory.fromJson(
          id: documentSnapshot.documentID,
          json: documentSnapshot.data,
        );
      }).toList();
    });
  }

  Widget _buildCategoryList(
      BuildContext context, AsyncSnapshot<List<ImageCategory>> snapshot) {
    if (!snapshot.hasData) {
      return Center(child: CircularProgressIndicator());
    }

    final categories = snapshot.data;

    return new GridView.builder(
      gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        crossAxisCount: 2,
      ),
      itemBuilder: (BuildContext context, int index) =>
          _buildCategoryItem(context, categories[index]),
      itemCount: categories.length,
    );
  }

  Widget _buildCategoryItem(BuildContext context, ImageCategory category) {
    return Material(
      borderRadius: BorderRadius.all(Radius.circular(4.0)),
      elevation: 3.0,
      child: InkWell(
        onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                return new ImageByCategoryPage(category);
              }),
            ),
        child: new Stack(
          children: <Widget>[
            FadeInImage(
              height: 400.0,
              placeholder: AssetImage('assets/picture.png'),
              image: NetworkImage(category.imageUrl),
              fit: BoxFit.cover,
            ),
            new Align(
              child: new Container(
                padding: new EdgeInsets.all(4.0),
                decoration: new BoxDecoration(
                  color: Colors.black54,
                ),
                child: new Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: new TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                  ),
                ),
                width: double.infinity,
              ),
              alignment: AlignmentDirectional.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ImageByCategoryPage extends StatefulWidget {
  final ImageCategory category;

  const ImageByCategoryPage(this.category, {Key key}) : super(key: key);

  @override
  _ImageByCategoryPageState createState() => new _ImageByCategoryPageState();
}

class _ImageByCategoryPageState extends State<ImageByCategoryPage> {
  ImageCategory category;
  final categoriesCollection = Firestore.instance.collection('categories');
  final imagesCollection = Firestore.instance.collection('images');

  StreamSubscription<DocumentSnapshot> subscription;

  @override
  void initState() {
    super.initState();
    category = widget.category;
    subscription = categoriesCollection
        .document(category.id)
        .snapshots()
        .listen((DocumentSnapshot documentSnapshot) {
      final newCategory = new ImageCategory.fromJson(
          id: documentSnapshot.documentID, json: documentSnapshot.data);
      setState(() => category = newCategory);
    });
  }

  @override
  void dispose() {
    super.dispose();
    subscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(category.name),
      ),
      body: new StreamBuilder<List<ImageModel>>(
        stream: _imageByCategoryIdStream,
        builder: _buildImageList,
      ),
    );
  }

  Stream<List<ImageModel>> get _imageByCategoryIdStream {
    return imagesCollection
        .where('categoryId', isEqualTo: category.id)
        .snapshots()
        .map((QuerySnapshot querySnapshot) {
      return querySnapshot.documents.map((documentSnapshot) {
        return ImageModel.fromJson(
          id: documentSnapshot.documentID,
          json: documentSnapshot.data,
        );
      }).toList();
    });
  }

  Widget _buildImageList(
      BuildContext context, AsyncSnapshot<List<ImageModel>> snapshot) {
    if (!snapshot.hasData) {
      return Center(child: CircularProgressIndicator());
    }

    final images = snapshot.data;

    if (images.isEmpty) {
      return new Center(
        child: Text(
          'Image list is empty!',
          style: Theme.of(context).textTheme.body1,
        ),
      );
    }

    return new StaggeredGridView.countBuilder(
      crossAxisCount: 4,
      itemCount: images.length,
      itemBuilder: (context, index) => _buildImageItem(context, images[index]),
      staggeredTileBuilder: (index) =>
          StaggeredTile.count(2, index.isEven ? 2 : 1),
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
    );
  }

  Widget _buildImageItem(BuildContext context, ImageModel image) {
    return Material(
      borderRadius: BorderRadius.all(Radius.circular(4.0)),
      elevation: 3.0,
      child: InkWell(
        onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => new ImageDetailPage(image),
              ),
            ),
        child: Hero(
          tag: image.id,
          child: FadeInImage(
            placeholder: AssetImage('assets/picture.png'),
            image: NetworkImage(image.imageUrl),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
