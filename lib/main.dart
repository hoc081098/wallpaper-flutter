import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallpaper/data/models/search_state.dart';
import 'package:wallpaper/screens/all_images_page.dart';
import 'package:wallpaper/screens/category_page.dart';
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
  int _selectedIndex = 0;
  List<Map<String, dynamic>> nav;
  Iterable<Widget> listTiles;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Widget _appBarTitle;
  Icon _actionIcon;

  // search functionality
  bool _isSearching = false;
  final _streamController = PublishSubject<String>();
  Stream<SearchImageState> _searchStream;
  final _imageCollection = Firestore.instance.collection('images');
  AnimationController _opacityController;
  Animation<double> _opacityAnim;

  // clear history functionality
  final StreamController clearStreamController =
      new StreamController.broadcast();

  @override
  void initState() {
    super.initState();
    nav = <Map<String, dynamic>>[
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
        'builder': (BuildContext context) => new RecentPage(
              clearStream: clearStreamController.stream,
              scaffoldKey: _scaffoldKey,
            ),
      },
    ];

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

    _appBarTitle = Text(nav[_selectedIndex]['title']);
    _actionIcon = Icon(Icons.search, color: Colors.white);

    _opacityController = new AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _opacityAnim = new Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _opacityController,
        curve: Interval(
          0.2,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    )..addListener(() => setState(() {}));
    _searchStream = _streamController
        .debounce(Duration(milliseconds: 300))
        .map((s) => s.trim())
        .distinct()
        .switchMap(_searchImage);
  }

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(context),
        appBar: _buildAppBar(context),
        body: _isSearching
            ? _buildSearchList(context)
            : nav[_selectedIndex]['builder'](context),
      ),
      onWillPop: () => _onWillPop(context),
    );
  }

  @override
  void dispose() {
    super.dispose();
    clearStreamController.close();
    _opacityController.dispose();
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

  AppBar _buildAppBar(BuildContext context) {
    final actions = <Widget>[
      IconButton(
        onPressed: _onPressIcon,
        icon: _actionIcon,
        tooltip: 'Search',
      ),
    ];

    if (_selectedIndex == 3 && !_isSearching) {
      actions.add(
        new PopupMenuButton(
          onSelected: (_) {
            debugPrint('onSelected');
            clearStreamController.add(null);
          },
          itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem(
                value: '',
                child: Text('Clear history'),
              )
            ];
          },
        ),
      );
    }

    return new AppBar(
      title: _appBarTitle,
      actions: actions,
    );
  }

  void _onPressIcon() {
    if (!_isSearching) {
      setState(() {
        _actionIcon = Icon(Icons.close, color: Colors.white);
        _appBarTitle = new FadeTransition(
          child: TextField(
            keyboardType: TextInputType.text,
            maxLines: 1,
            onChanged: (query) => _streamController.add(query),
            style: TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              prefixIcon: new Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(Icons.search),
              ),
              hintText: 'Search image...',
              border: UnderlineInputBorder(),
            ),
          ),
          opacity: _opacityAnim,
        );

        _opacityController.reset();
        _isSearching = true;
        _opacityController.forward();
      });
    } else {
      _opacityController.reverse(from: _opacityController.upperBound).then((_) {
        setState(() {
          _isSearching = false;
          _appBarTitle = Text(nav[_selectedIndex]['title']);
          _actionIcon = Icon(Icons.search, color: Colors.white);
        });
      });
    }
  }

  Stream<SearchImageState> _searchImage(String value) async* {
    debugPrint('Value = $value');
    Stream<QuerySnapshot> stream = value.isEmpty
        ? _imageCollection.snapshots()
        : _imageCollection
        .orderBy('name')
        .startAt([value]).endAt(["$value" + "\u{f8ff}"]).snapshots();
    yield LoadingState();
    try {
      await for (var result in stream
          .map(utils.mapper)
          .map<SearchImageState>((images) => SuccessState(images))) {
        yield result;
      }
    } catch (e) {
      yield ErrorState(e);
    }
  }

  Widget _buildSearchList(BuildContext context) {
    return new FadeTransition(
      child: Container(
        decoration: BoxDecoration(
          color: Theme
              .of(context)
              .backgroundColor,
        ),
        child: _buildStreamBuilder(),
      ),
      opacity: _opacityAnim,
    );
  }

  Widget _buildStreamBuilder() {
    return new StreamBuilder<SearchImageState>(
      stream: _searchStream.distinct(),
      builder:
          (BuildContext context, AsyncSnapshot<SearchImageState> snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Text(
              'Search somthing...',
              style: Theme
                  .of(context)
                  .textTheme
                  .subhead,
            ),
          );
        }

        final data = snapshot.data;
        debugPrint('DEBUG $data');

        if (data is ErrorState) {
          return Center(
            child: Text(
              data.error.toString(),
              style: Theme
                  .of(context)
                  .textTheme
                  .subhead,
            ),
          );
        }

        if (data is LoadingState) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        if (data is SuccessState) {
          var images = data.images;
          debugPrint('Length: ${images.length}');
          return new Column(
            children: <Widget>[
              new Padding(
                padding: const EdgeInsets.all(8.0),
                child: new Text('Found ${images.length} results'),
              ),
              new Expanded(
                child: new GridView.builder(
                  gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2.0,
                    mainAxisSpacing: 2.0,
                    childAspectRatio: 9 / 16,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final item = images[index];
                    return new FadeInImage.assetNetwork(
                      fit: BoxFit.cover,
                      placeholder: '',
                      image: item.thumbnailUrl,
                    );
                  },
                  itemCount: images.length,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Future<bool> _onWillPop(BuildContext context) {
    return showDialog<bool>(
        context: context,
        builder: (context) {
          return new AlertDialog(
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
        });
  }
}
