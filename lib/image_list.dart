import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:wallpaper/data/models/image_model.dart';
import 'package:wallpaper/screens/image_detail.dart';

class StaggeredImageList extends StatelessWidget {
  final Stream<List<ImageModel>> stream;

  const StaggeredImageList(this.stream, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ImageModel>>(
      stream: stream,
      builder: _buildImageList,
    );
  }

  Widget _buildImageList(
      BuildContext context, AsyncSnapshot<List<ImageModel>> snapshot) {
    if (snapshot.hasError) {
      debugPrint('>>> Error: ${snapshot.error}');
      return Center(
        child: Text(
          'An error occurred',
          style: Theme.of(context).textTheme.body1,
        ),
      );
    }

    if (!snapshot.hasData) {
      return Center(child: CircularProgressIndicator());
    }

    final images = snapshot.data;

    if (images.isEmpty) {
      return Center(
        child: Text(
          'Image list is empty!',
          style: Theme.of(context).textTheme.body1,
        ),
      );
    }

    return StaggeredGridView.countBuilder(
      crossAxisCount: 4,
      itemCount: images.length,
      itemBuilder: (context, index) => _buildImageItem(context, images[index]),
      staggeredTileBuilder: (index) =>
          StaggeredTile.count(2, index.isEven ? 2 : 1),
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
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
          child: CachedNetworkImage(
            imageUrl: image.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(
                  constraints: BoxConstraints.expand(),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: Image.asset(
                          'assets/picture.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2,),
                        ),
                      )
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class ImageItem extends StatelessWidget {
  final ImageModel item;

  const ImageItem(this.item, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageDetailPage(item),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Hero(
            child: CachedNetworkImage(
              imageUrl: item.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(
                    constraints: BoxConstraints.expand(),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Image.asset(
                            'assets/picture.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2,),
                          ),
                        )
                      ],
                    ),
                  ),
            ),
            tag: item.id,
          ),
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Colors.black, Colors.transparent],
                  begin: AlignmentDirectional.bottomCenter,
                  end: AlignmentDirectional.topCenter,
                ),
              ),
              alignment: AlignmentDirectional.center,
              child: Text(
                item.name,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme
                    .of(context)
                    .textTheme
                    .subhead
                    .copyWith(fontSize: 14.0),
              ),
            ),
          )
        ],
      ),
    );
  }
}
