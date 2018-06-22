import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallpaper/category_page.dart';

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
        title: _buildTitle(_selectedIndex),
      ),
      body: _buildBody(_selectedIndex),
    );
  }

  Text _buildTitle(int index) {
    switch (index) {
      case 0:
        return Text('Category');
      case 1:
        return Text('All images');
      case 2:
        return Text('Recents');
      default:
        throw StateError("Error occurred");
    }
  }

  Widget _buildBody(int index) {
    switch (index) {
      case 0:
        return CategoryPage();
      case 1:
        return AllPage();
      case 2:
        return RecentsPage();
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
            trailing: new Icon(Icons.category),
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('All'),
            trailing: new Icon(Icons.image),
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('Recents'),
            trailing: new Icon(Icons.history),
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class AllPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new AllImagesList();
  }
}

class AllImagesList extends ImagesPage {
  final imagesCollection = Firestore.instance.collection('images');

  @override
  Stream<QuerySnapshot> get stream => imagesCollection.snapshots();
}

class RecentsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new RecentsList();
  }
}

class RecentsList extends ImagesPage {
  final imagesCollection = Firestore.instance.collection('images');

  @override
  Stream<QuerySnapshot> get stream {
    return imagesCollection
        .orderBy('uploadedTime', descending: true)
        .limit(10)
        .snapshots();
  }
}
