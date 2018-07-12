import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallpaper/data/models/image_model.dart';
import 'package:wallpaper/image_list.dart';
import 'package:wallpaper/utils.dart';

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
            .limit(15)
            .snapshots()
            .map(mapper);
      case Trending.viewCount:
        return imagesCollection
            .orderBy('viewCount', descending: true)
            .limit(15)
            .snapshots()
            .map(mapper);
    }
    return null;
  }
}
