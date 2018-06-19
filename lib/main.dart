import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:wallpaper/category_page.dart';
import 'package:wallpaper/image_detail.dart';
import 'package:wallpaper/models.dart';

void main() => runApp(MyApp());

const String channel = "my_flutter_wallpaper";
const String setWallpaper = "setWallpaper";

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wallpaper',
      theme: ThemeData.dark(),
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

class _AllPageState extends State<AllPage> {
  final imagesCollection = Firestore.instance.collection('images');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ImageModel>>(
      stream: imagesCollection.snapshots().map((QuerySnapshot querySnapshot) {
        return querySnapshot.documents.map((documentSnapshot) {
          return ImageModel.fromJson(
            id: documentSnapshot.documentID,
            json: documentSnapshot.data,
          );
        }).toList();
      }),
      builder:
          (BuildContext context, AsyncSnapshot<List<ImageModel>> snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final images = snapshot.data;

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
            placeholder: AssetImage('assets/picture.png'),
            image: NetworkImage(image.imageUrl),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
