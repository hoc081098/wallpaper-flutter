import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallpaper/data/models/image_category_model.dart';
import 'package:wallpaper/image_list.dart';
import 'package:wallpaper/utils.dart';

class CategoryPage extends StatelessWidget {
  final categoriesCollection = Firestore.instance.collection('categories');

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).backgroundColor,
      child: StreamBuilder<List<ImageCategory>>(
        stream: categoriesStream,
        builder: _buildCategoryList,
      ),
    );
  }

  Stream<List<ImageCategory>> get categoriesStream {
    return categoriesCollection
        .orderBy('name')
        .snapshots()
        .map((QuerySnapshot querySnapshot) {
      return querySnapshot.documents.map((DocumentSnapshot documentSnapshot) {
        return ImageCategory.fromJson(
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

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
            return ImagesByCategoryPage(category);
          }),
        ),
        child: Stack(
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: category.imageUrl,
              fit: BoxFit.cover,
              height: 400,
              placeholder: (context, url) => Container(
                constraints: BoxConstraints.expand(),
                child: Image.asset(
                  'assets/picture.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Align(
              child: Container(
                padding: EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Colors.black54,
                ),
                child: Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
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

class ImagesByCategoryPage extends StatelessWidget {
  final ImageCategory category;
  final imagesCollection = Firestore.instance.collection('images');

  ImagesByCategoryPage(this.category, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: Container(
        color: Theme.of(context).backgroundColor,
        child: StaggeredImageList(
          imagesCollection
              .where('categoryId', isEqualTo: category.id)
              .orderBy('name')
              .snapshots()
              .map(mapper),
        ),
      ),
    );
  }
}
