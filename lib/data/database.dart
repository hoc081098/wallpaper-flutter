import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wallpaper/data/models/image_model.dart';

class ImageDB {
  static const dbName = "images.db";
  static const tableRecent = 'recents';
  static const tableFavorites = 'favorites';
  static const createdAtDesc = 'datetime(createdAt) DESC';
  static const nameAsc = 'name ASC';

  Database _db;
  static ImageDB _instance;

  ImageDB._internal();

  factory ImageDB.getInstance() => _instance ??= ImageDB._internal();

  Future<Database> get db async => _db ??= await open();

  Future<Database> open() async {
    final directory = await getApplicationDocumentsDirectory();
    String path = join(directory.path, dbName);
    return await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''CREATE TABLE $tableRecent( 
        id TEXT PRIMARY KEY UNIQUE NOT NULL, 
        name TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        thumbnailUrl TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        uploadedTime TEXT NOT NULL,
        viewTime TEXT NOT NULL
      )''');
      await db.execute('''CREATE TABLE $tableFavorites(
        id TEXT PRIMARY KEY UNIQUE NOT NULL, 
        name TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        thumbnailUrl TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        uploadedTime TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )''');
    });
  }

  Future<Null> close() async {
    final dbClient = await db;
    await dbClient.close();
  }

  ///
  /// Recent imags
  ///

  Future<int> insertRecentImage(ImageModel image) async {
    final values = (image..viewTime = DateTime.now()).toJson();
    final dbClient = await db;
    return await dbClient.insert(
      tableRecent,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateRecentImage(ImageModel image) async {
    final dbClient = await db;
    return await dbClient.update(
      tableRecent,
      image.toJson(),
      where: "id = ?",
      whereArgs: [image.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteRecentImageById(String id) async {
    final dbClient = await db;
    return await dbClient.delete(
      tableRecent,
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future<int> deleteAllRecentImages() async {
    final dbClient = await db;
    return await dbClient.delete(tableRecent, where: '1');
  }

  Future<ImageModel> getRecentImageById(String id) async {
    final dbClient = await db;
    final maps = await dbClient.query(
      tableRecent,
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty
        ? ImageModel.fromJson(id: maps.first['id'], json: maps.first)
        : null;
  }

  Future<List<ImageModel>> getRecentImages({int limit}) async {
    final dbClient = await db;

    final maps = await (limit != null
        ? dbClient.query(
            tableRecent,
            orderBy: 'datetime(viewTime) DESC',
            limit: limit,
          )
        : dbClient.query(
            tableRecent,
            orderBy: 'datetime(viewTime) DESC',
          ));
    return maps
        .map((json) => ImageModel.fromJson(id: json['id'], json: json))
        .toList();
  }

  ///
  /// Favorite images
  ///

  Future<List<ImageModel>> getFavoriteImages(
      {String orderBy: createdAtDesc, int limit}) async {
    final dbClient = await db;
    final maps = await (limit != null
        ? dbClient.query(
            tableFavorites,
            orderBy: orderBy,
            limit: limit,
          )
        : dbClient.query(
            tableFavorites,
            orderBy: orderBy,
          ));
    return maps
        .map((json) => ImageModel.fromJson(id: json['id'], json: json))
        .toList();
  }

  Future<int> insertFavoriteImage(ImageModel image) async {
    final values = image.toJson();
    values['createdAt'] = DateTime.now().toIso8601String();
    values.remove('viewTime');

    final dbClient = await db;
    return await dbClient.insert(
      tableFavorites,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateFavoriteImage(ImageModel image) async {
    final dbClient = await db;
    return dbClient.rawUpdate('''
      UPDATE $tableFavorites
      SET name = ?, imageUrl = ?, thumbnailUrl = ?, categoryId = ?, uploadedTime = ?
      WHERE id = ?
    ''', <String>[
      image.name,
      image.imageUrl,
      image.thumbnailUrl,
      image.categoryId,
      image.uploadedTime.toIso8601String(),
      image.id,
    ]);
  }

  Future<int> deleteFavoriteImageById(String id) async {
    final dbClient = await db;
    return await dbClient.delete(
      tableFavorites,
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future<bool> isFavoriteImage(String id) async {
    final dbClient = await db;
    final maps = await dbClient.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM $tableFavorites WHERE id=? LIMIT 1)',
      [id],
    );
    var values;
    return maps.isNotEmpty &&
        (values = maps[0].values).isNotEmpty &&
        values.first == 1;
  }
}
