import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallpaper/data/database.dart';
import 'package:wallpaper/data/models/search_state.dart';
import 'package:wallpaper/image_list.dart';
import 'package:wallpaper/screens/category_page.dart';
import 'package:wallpaper/screens/downloads_page.dart';
import 'package:wallpaper/screens/favorites_page.dart';
import 'package:wallpaper/screens/newest_image_page.dart';
import 'package:wallpaper/screens/recent_images_page.dart';
import 'package:wallpaper/screens/trending_images_page.dart';
import 'package:wallpaper/screens/upload_page.dart';
import 'package:wallpaper/utils.dart' as utils;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wallpaper',
      theme: ThemeData(
        fontFamily: 'NunitoSans',
        brightness: Brightness.dark,
        primaryColor: Color(0xff070b16),
        primaryColorDark: Color(0xff070a11),
        primaryColorLight: Color(0xff141622),
        accentColor: Color(0xffffC126),
        backgroundColor: Color(0xff0b101d),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Drawer related
  int selectedIndex = 0;
  List<Map<String, dynamic>> nav;
  List<Widget> listTiles;

  /// search functionality
  bool isSearching = false;
  final searchTermS = PublishSubject<String>();
  Stream<SearchImageState> _searchState$;

  /// clear history functionality
  final clearStreamController = StreamController<void>.broadcast();

  /// sort order favorites
  final sortOrderS = BehaviorSubject.seeded(ImageDB.createdAtDesc);

  @override
  void initState() {
    super.initState();

    nav = [
      {
        'title': 'Categories',
        'icon': Icons.category,
        'builder': (BuildContext context) => CategoryPage(),
      },
      {
        'title': 'Newest images',
        'icon': Icons.update,
        'builder': (BuildContext context) => NewestPage(),
      },
      {
        'title': 'Recent images',
        'icon': Icons.history,
        'builder': (BuildContext context) {
          return RecentPage(
            clearStream: clearStreamController.stream,
            scaffoldKey: scaffoldKey,
          );
        },
      },
      {
        'title': 'Favorites',
        'icon': Icons.favorite,
        'builder': (BuildContext context) => FavoritesPage(sortOrderS.stream),
      },
      {
        'title': 'Downloaded',
        'icon': Icons.cloud_done,
        'builder': (BuildContext context) => DownloadedPage(),
      },
    ];

    listTiles = nav
        .asMap()
        .map((index, m) {
          return MapEntry(
            index,
            ListTile(
              title: Text(m['title']),
              trailing: Icon(m['icon']),
              onTap: () {
                if (isSearching) {
                  setState(() {
                    isSearching = false;
                    selectedIndex = index;
                  });
                } else {
                  setState(() => selectedIndex = index);
                }
                Navigator.pop(context);
              },
            ),
          );
        })
        .values
        .toList();

    _searchState$ = searchTermS
        .debounceTime(Duration(milliseconds: 500))
        .map((s) => s.trim())
        .distinct()
        .switchMap(_searchImage)
        .shareValueSeeded(null);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        key: scaffoldKey,
        drawer: _buildDrawer(context),
        appBar: _buildAppBar(context),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: isSearching
              ? _buildSearchList(context)
              : nav[selectedIndex]['builder'](context),
        ),
      ),
      onWillPop: () => _onWillPop(context),
    );
  }

  @override
  void dispose() {
    super.dispose();
    clearStreamController.close();
    sortOrderS.close();
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Theme.of(context).backgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              child: Text(
                'Wallpaper HD Flutter',
                style: Theme.of(context)
                    .textTheme
                    .title
                    .copyWith(color: Colors.white),
              ),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/drawer_header_image.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black26,
                    BlendMode.darken,
                  ),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 4.0,
                    spreadRadius: 4.0,
                  )
                ],
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
              ),
            ),
            listTiles[0],
            listTiles[1],
            ListTile(
              title: Text('Trending image'),
              trailing: Icon(Icons.trending_up),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TrendingPage()),
                );
              },
            ),
            ListTile(
              title: Text('Upload image'),
              trailing: Icon(Icons.cloud_upload),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UploadPage()),
                );
              },
            ),
            Divider(color: Colors.white30),
            listTiles[2],
            listTiles[3],
            listTiles[4],
            Divider(color: Colors.white30),
            AboutListTile(
              applicationName: 'Flutter wallpaper HD',
              applicationIcon: FlutterLogo(),
              applicationVersion: '1.0.0',
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: isSearching
          ? TextField(
              keyboardType: TextInputType.text,
              maxLines: 1,
              onChanged: searchTermS.add,
              style: TextStyle(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.search),
                ),
                hintText: 'Search image...',
                border: UnderlineInputBorder(),
              ),
            )
          : Text(nav[selectedIndex]['title']),
      actions: <Widget>[
        IconButton(
          onPressed: () => setState(() => isSearching = !isSearching),
          icon: isSearching
              ? Icon(Icons.close, color: Colors.white)
              : Icon(Icons.search, color: Colors.white),
          tooltip: 'Search',
        ),
        if (!isSearching && selectedIndex == 2) //History page
          PopupMenuButton(
            onSelected: (_) => clearStreamController.add(null),
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: '',
                  child: Text('Clear history'),
                )
              ];
            },
          ),
        if (!isSearching && selectedIndex == 3) //Favorite page
          PopupMenuButton<String>(
            onSelected: (v) => sortOrderS.add(v),
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: ImageDB.createdAtDesc,
                  child: Text('Time descending'),
                ),
                PopupMenuItem<String>(
                  value: ImageDB.nameAsc,
                  child: Text('Name ascending'),
                ),
              ];
            },
          ),
      ],
    );
  }

  Widget _buildSearchList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).backgroundColor,
      ),
      child: StreamBuilder<SearchImageState>(
        stream: _searchState$,
        builder:
            (BuildContext context, AsyncSnapshot<SearchImageState> snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Text(
                'Search something...',
                style: Theme.of(context).textTheme.subhead,
              ),
            );
          }

          final data = snapshot.data;
          debugPrint('DEBUG $data');

          if (data is ErrorState) {
            return Center(
              child: Text(
                data.error.toString(),
                style: Theme.of(context).textTheme.subhead,
              ),
            );
          }

          if (data is LoadingState) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (data is SuccessState) {
            final images = data.images;
            debugPrint('Length: ${images.length}');
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Found ${images.length} results'),
                ),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2.0,
                      mainAxisSpacing: 2.0,
                      childAspectRatio: 9 / 16,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      return ImageItem(images[index]);
                    },
                    itemCount: images.length,
                  ),
                ),
              ],
            );
          }

          return null;
        },
      ),
    );
  }

  static Future<bool> _onWillPop(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Exit app'),
          content: Text('Do you want to exit app?'),
          actions: <Widget>[
            FlatButton(
              child: Text('No'),
              onPressed: () => Navigator.pop(context, false),
            ),
            FlatButton(
              child: Text('Yes'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );
  }
}

Stream<SearchImageState> _searchImage(String searchTerm) async* {
  print('searchTerm = $searchTerm');

  yield LoadingState();
  try {
    final querySnapshot =
        await Firestore.instance.collection('images').getDocuments();
    final images = querySnapshot.documents
        .map(utils.mapperImageModel)
        .where(
          (image) => searchTerm.isEmpty
              ? true
              : (image.name ?? '')
                  .toLowerCase()
                  .contains(searchTerm.toLowerCase()),
        )
        .toList();

    yield SuccessState(images);
  } catch (e) {
    yield ErrorState(e);
  }
}
