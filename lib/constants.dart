import 'package:flutter/services.dart';

const String channel = 'my_flutter_wallpaper';
const methodChannel = MethodChannel(channel);

/// Set image as wallpaper
/// Arguments: [List] of [String]s, is path of image file, start from folder in external storage directory
/// Return   : a [String] when success or [PlatformException] when failed
/// Example:
/// path of image: 'external storage directory'/flutterImages/image.png
///   methodChannel.invokeMethod(
///      setWallpaper,
///      <String>['flutterImages', 'image.png'],
///   );
const String setWallpaper = 'setWallpaper';

/// Scan image file, after scan, we can see image in gallery
/// Arguments: [List] of [String]s, is path of image file, start from folder in external storage directory
/// Return   : a [String] when success or [PlatformException] when failed
/// Example:
/// path of image: 'external storage directory'/flutterImages/image.png
///   methodChannel.invokeMethod(scanFile, <String>[
///     'flutterImages',
///     'image.png'
///   ]);
const String scanFile = 'scanFile';

/// Share image to facebook
/// Arguments: [String], it is image url
/// Return   : [Null]
/// Example:
/// methodChannel.invokeMethod(shareImageToFacebook, url);
const String shareImageToFacebook = 'shareImageToFacebook';

/// Resize image
/// Arguments: [Map], keys is [String]s, values is dynamic type
/// Return   : a [Uint8List] when success or [PlatformException] when failed
/// Example:
/// final Uint8List outBytes = await methodChannel.invokeMethod(
///   resizeImage,
///   <String, dynamic>{
///     'bytes': bytes,
///     'width': 720,
///     'height': 1280,
///   },
/// );
const String resizeImage = 'resizeImage';
