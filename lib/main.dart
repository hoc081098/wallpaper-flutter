import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper',
      theme: ThemeData.light(),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Text('App bar title'),
      ),
      body: _buildBody(_selectedIndex),
    );
  }

  Widget _buildBody(int index) {
    switch (index) {
      case 0:
        return CategoryPage();
      case 1:
        return AllPage();
      default:
        throw StateError("Error occurred");
    }
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            child: Text(
              'Drawer Header',
              style: Theme
                  .of(context)
                  .textTheme
                  .title
                  .copyWith(color: Colors.white),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.pinkAccent.withOpacity(0.8),
                  Colors.blueAccent.withOpacity(0.8)
                ],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4.0,
                  spreadRadius: 4.0,
                )
              ],
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
          ),
          ListTile(
            title: Text('Category'),
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('All'),
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class AllPage extends StatefulWidget {
  @override
  _AllPageState createState() => _AllPageState();
}

class ImageModel {
  final String name;
  final String imageUrl;
  final String id;

  ImageModel({this.name, this.imageUrl, this.id});

  @override
  String toString() => 'ImageModel{name: $name, imageUrl: $imageUrl, id: $id}';
}

class _AllPageState extends State<AllPage> {
  final imagesCollection = Firestore.instance.collection('images');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ImageModel>>(
      stream: imagesCollection.snapshots().map((QuerySnapshot querySnapshot) {
        return querySnapshot.documents.map((documentSnapshot) {
          return ImageModel(
            name: documentSnapshot['name'],
            imageUrl: documentSnapshot['imageUrl'],
            id: documentSnapshot.documentID,
          );
        }).toList();
      }),
      builder:
          (BuildContext context, AsyncSnapshot<List<ImageModel>> snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final images = snapshot.data;
        debugPrint(images.toString());

        return StaggeredGridView.countBuilder(
          crossAxisCount: 4,
          itemCount: images.length,
          itemBuilder: (context, index) =>
              _buildImageItem(context, images[index]),
          staggeredTileBuilder: (index) =>
              StaggeredTile.count(2, index.isEven ? 2 : 1),
          mainAxisSpacing: 8.0,
          crossAxisSpacing: 8.0,
        );
      },
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
                builder: (context) => ImageDetailPage(image),
              ),
            ),
        child: Hero(
          tag: image.id,
          child: FadeInImage(
            placeholder: AssetImage(''),
            image: NetworkImage(image.imageUrl),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class CategoryPage extends StatefulWidget {
  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Category page'),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    imageModel = widget.imageModel;
    subscription = imagesCollection
        .document('${imageModel.id}')
        .snapshots()
        .listen((DocumentSnapshot documentSnapshot) {
      setState(() {
        final newImageModel = new ImageModel(
          name: documentSnapshot['name'],
          imageUrl: documentSnapshot['imageUrl'],
          id: documentSnapshot.documentID,
        );
        setState(() => imageModel = newImageModel);
      });
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
      body: new Container(
        decoration: new BoxDecoration(
          gradient: new LinearGradient(
            colors: <Color>[
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.9),
            ],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
        ),
        padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
        child: new Stack(
          children: <Widget>[
            new Center(
              child: new Stack(
                children: <Widget>[
                  new Hero(
                    tag: imageModel.id,
                    child: new FadeInImage(
                      placeholder: new AssetImage(''),
                      image: new NetworkImage(imageModel.imageUrl),
                    ),
                  ),
                  new Positioned(
                    child: new Container(
                      decoration: new BoxDecoration(
                        gradient: new LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                          begin: AlignmentDirectional.topCenter,
                          end: AlignmentDirectional.bottomCenter,
                        ),
                      ),
                      child: new Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: new Text(
                          imageModel.name,
                          style: new TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    bottom: 0.0,
                    left: 0.0,
                    right: 0.0,
                  )
                ],
              ),
            ),
            new Positioned(
              child: new AppBar(
                elevation: 0.0,
                backgroundColor: Colors.transparent,
                leading: new IconButton(
                  icon: new Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              top: 0.0,
              left: 0.0,
              right: 0.0,
            ),
          ],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () {},
        child: new Icon(Icons.arrow_downward),
      ),
    );
  }
}
