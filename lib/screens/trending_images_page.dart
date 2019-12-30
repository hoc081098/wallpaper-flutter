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

class TrendingPage extends StatefulWidget {
  @override
  _TrendingPageState createState() => _TrendingPageState();
}

class _TrendingPageState extends State<TrendingPage> {
  final selectedS = BehaviorSubject<Trending>.seeded(Trending.downloadCount);
  ValueConnectableStream<List<ImageModel>> images$;
  StreamSubscription subscription;

  @override
  void initState() {
    super.initState();
    images$ = selectedS.distinct().switchMap(stream).publishValueSeeded(null);
    subscription = images$.connect();
  }

  @override
  void dispose() {
    subscription.cancel();
    selectedS.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trendings'),
        actions: _buildActions(),
      ),
      body: Container(
        color: Theme.of(context).backgroundColor,
        child: StaggeredImageList(images$),
      ),
    );
  }

  List<Widget> _buildActions() {
    return <Widget>[
      StreamBuilder(
        stream: selectedS,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          return DropdownButton<Trending>(
            items: Trending.values.map((e) {
              return DropdownMenuItem(
                child: Text(trendingToString(e)),
                value: e,
              );
            }).toList(),
            value: snapshot.data,
            onChanged: selectedS.add,
          );
        },
      ),
    ];
  }

  static Stream<List<ImageModel>> stream(Trending selected) {
    return Firestore.instance
        .collection('images')
        .orderBy(trendingToFieldName(selected), descending: true)
        .limit(15)
        .snapshots()
        .map(mapper);
  }
}
