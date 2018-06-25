import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallpaper/category_page.dart';
import 'package:wallpaper/database.dart';
import 'package:wallpaper/image_list.dart';
import 'package:wallpaper/models.dart';
import 'package:wallpaper/upload_page.dart';

void main() => runApp(MyApp());

const String channel = "my_flutter_wallpaper";
const String setWallpaper = "setWallpaper";
const String scanFile = "scanFile";
const String shareImageToFacebook = 'shareImageToFacebook';

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
  static final nav = <Map<String, dynamic>>[
    {
      'title': 'Categories',
      'icon': Icons.category,
      'builder': (BuildContext context) => new CategoryPage(),
    },
    {
      'title': 'All images',
      'icon': Icons.image,
      'builder': (BuildContext context) => new AllPage(),
    },
    {
      'title': 'Newest images',
      'icon': Icons.update,
      'builder': (BuildContext context) => new NewestPage(),
    },
    {
      'title': 'Recent images',
      'icon': Icons.history,
      'builder': (BuildContext context) => new RecentPage(),
    },
  ];
  Iterable<Widget> listTiles;

  @override
  void initState() {
    super.initState();
    listTiles = nav.asMap().map((index, m) {
      return MapEntry(
        index,
        ListTile(
          title: Text(m['title']),
          trailing: Icon(m['icon']),
          onTap: () {
            setState(() => _selectedIndex = index);
            Navigator.pop(context);
          },
        ),
      );
    }).values;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Text(nav[_selectedIndex]['title']),
      ),
      body: nav[_selectedIndex]['builder'](context),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: Text(
              'Wallpaper HD Flutter',
              style: Theme
                  .of(context)
                  .textTheme
                  .title
                  .copyWith(color: Colors.white),
            ),
            decoration: BoxDecoration(
              image: new DecorationImage(
                image: new AssetImage('assets/drawer_header_image.jpg'),
                fit: BoxFit.cover,
                colorFilter: new ColorFilter.mode(
                  Colors.black26,
                  BlendMode.darken,
                ),
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
          listTiles,
          ListTile(
            title: Text('Trending image'),
            trailing: new Icon(Icons.trending_up),
            onTap: () {
              Navigator.push(
                context,
                new MaterialPageRoute(builder: (context) => new TrendingPage()),
              );
            },
          ),
          ListTile(
            title: Text('Upload image'),
            trailing: new Icon(Icons.cloud_upload),
            onTap: () {
              Navigator.push(
                context,
                new MaterialPageRoute(builder: (context) => new UploadPage()),
              );
            },
          ),
        ].expand<Widget>((i) => i is Iterable ? i : [i]).toList(),
      ),
    );
  }
}

class AllPage extends StatelessWidget {
  final imagesCollection = Firestore.instance.collection('images');

  @override
  Widget build(BuildContext context) {
    return new ImageList(imagesCollection.snapshots().map(mapper));
  }
}

class NewestPage extends StatelessWidget {
  final imagesCollection = Firestore.instance.collection('images');

  @override
  Widget build(BuildContext context) {
    return new ImageList(
      imagesCollection
          .orderBy('uploadedTime', descending: true)
          .limit(15)
          .snapshots()
          .map(mapper),
    );
  }
}

class RecentPage extends StatelessWidget {
  final imageDb = new ImageDb.getInstance();

  @override
  Widget build(BuildContext context) {
    return new ImageList(imageDb.getImages(20).asStream());
  }
}

class TrendingPage extends StatefulWidget {
  @override
  _TrendingPageState createState() => new _TrendingPageState();
}

enum Trending { downloadCount, viewCount }

String trendingToString(Trending trending) {
  switch (trending) {
    case Trending.downloadCount:
      return "Download count";
    case Trending.viewCount:
      return "View count";
  }
  return "";
}

class _TrendingPageState extends State<TrendingPage> {
  Trending _selected = Trending.downloadCount;
  final imagesCollection = Firestore.instance.collection('images');

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: Text('Trending images'),
        actions: _buildActions(),
      ),
      body: new ImageList(stream(_selected)),
    );
  }

  List<Widget> _buildActions() {
    return <Widget>[
      new DropdownButton<Trending>(
        items: Trending.values.map((e) {
          return new DropdownMenuItem(
            child: new Text(trendingToString(e)),
            value: e,
          );
        }).toList(),
        value: _selected,
        onChanged: (newValue) => setState(() => _selected = newValue),
      ),
    ];
  }

  Stream<List<ImageModel>> stream(Trending selected) {
    switch (selected) {
      case Trending.downloadCount:
        return imagesCollection
            .orderBy('downloadCount', descending: true)
            .snapshots()
            .map(mapper);
      case Trending.viewCount:
        return imagesCollection
            .orderBy('viewCount', descending: true)
            .snapshots()
            .map(mapper);
    }
    return null;
  }
}
