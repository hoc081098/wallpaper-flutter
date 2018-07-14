import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallpaper/data/models/image_model.dart';
import 'package:wallpaper/image_list.dart';
import 'package:wallpaper/utils.dart';

enum Trending { downloadCount, viewCount }

String trendingToString(Trending trending) {
  switch (trending) {
    case Trending.downloadCount:
      return 'Download count';
    case Trending.viewCount:
      return 'View count';
  }
  return '';
}

String trendingToFieldName(Trending trending) {
  switch (trending) {
    case Trending.downloadCount:
      return 'downloadCount';
    case Trending.viewCount:
      return 'viewCount';
  }
  return '';
}

class TrendingPage extends StatelessWidget {
  final _selected =
      new BehaviorSubject<Trending>(seedValue: Trending.downloadCount);
  final imagesCollection = Firestore.instance.collection('images');

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: Text('Trending images'),
        actions: _buildActions(),
      ),
      body: new StaggeredImageList(_selected.distinct().switchMap(stream)),
    );
  }

  List<Widget> _buildActions() {
    return <Widget>[
      new StreamBuilder(
        stream: _selected.distinct(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          return new DropdownButton<Trending>(
            items: Trending.values.map((e) {
              return new DropdownMenuItem(
                child: new Text(trendingToString(e)),
                value: e,
              );
            }).toList(),
            value: snapshot.data,
            onChanged: (newValue) => _selected.add(newValue),
          );
        },
      ),
    ];
  }

  Stream<List<ImageModel>> stream(Trending selected) {
    return imagesCollection
        .orderBy(trendingToFieldName(selected), descending: true)
        .limit(15)
        .snapshots()
        .map(mapper);
  }
}
