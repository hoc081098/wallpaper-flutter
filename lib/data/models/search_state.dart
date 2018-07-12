import 'package:collection/collection.dart' show ListEquality;
import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:wallpaper/data/models/image_model.dart';

@immutable
class SearchImageState {}

class LoadingState extends SearchImageState {
  @override
  String toString() => 'LoadingState';
}

class SuccessState extends SearchImageState {
  final List<ImageModel> images;
  static const listEquality = ListEquality();

  SuccessState(this.images);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuccessState &&
          runtimeType == other.runtimeType &&
          listEquality.equals(images, other.images);

  @override
  int get hashCode => listEquality.hash(images);

  @override
  String toString() => 'SuccessState{images: $images}';
}

class ErrorState extends SearchImageState {
  final error;

  ErrorState(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorState &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'ErrorState{error: $error}';
}
