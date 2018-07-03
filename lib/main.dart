import 'package:flutter/material.dart';
import 'package:wallpaper/screens/all_images_page.dart';
import 'package:wallpaper/screens/category_page.dart';
import 'package:wallpaper/screens/newest_image_page.dart';
import 'package:wallpaper/screens/recent_images_page.dart';
import 'package:wallpaper/screens/trending_images_page.dart';
import 'package:wallpaper/screens/upload_page.dart';

void main() => runApp(MyApp());

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
          new AboutListTile(
            applicationName: 'Flutter wallpaper HD',
            applicationIcon: new FlutterLogo(),
            applicationVersion: '1.0.0',
          ),
        ].expand<Widget>((i) => i is Iterable ? i : [i]).toList(),
      ),
    );
  }
}
