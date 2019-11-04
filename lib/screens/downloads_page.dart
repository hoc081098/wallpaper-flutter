import 'package:flutter/material.dart';
import 'package:wallpaper/data/database.dart';

class DownloadedPage extends StatefulWidget {
  @override
  _DownloadedPageState createState() => _DownloadedPageState();
}

class _DownloadedPageState extends State<DownloadedPage> {
  @override
  void initState() {
    super.initState();
    ImageDB.getInstance().getDownloadedImages().then(print);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: Text('D'),
      ),
    );
  }
}
