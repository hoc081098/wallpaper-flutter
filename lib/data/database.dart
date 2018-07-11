import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wallpaper/data/models/image_model.dart';

class ImageDb {
  static const dbName = "images.db";
  static const tableRecent = 'recents';

  Database _db;
  static ImageDb _instance;

  ImageDb._internal();

  factory ImageDb.getInstance() => _instance ??= ImageDb._internal();

  Future<Database> get db async => _db ??= await open();

  Future<Database> open() async {
    final directory = await getApplicationDocumentsDirectory();
    String path = join(directory.path, dbName);
    return await openDatabase(path, version: 1,
        onCreate: (db, newVersion) async {
      await db.execute('''CREATE TABLE $tableRecent( 
        id TEXT PRIMARY KEY UNIQUE NOT NULL, 
        name TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        thumbnailUrl TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        uploadedTime TEXT NOT NULL,
        viewTime TEXT NOT NULL
      )''');
    });
  }

  close() async {
    final dbClient = await db;
    await dbClient.close();
  }

  Future<int> insert(ImageModel image) async {
    final values = (image..viewTime = DateTime.now()).toJson();
    final dbClient = await db;
    return await dbClient.insert(
      tableRecent,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(ImageModel image) async {
    final dbClient = await db;
    return await dbClient.update(
      tableRecent,
      image.toJson(),
      where: "id = ?",
      whereArgs: [image.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> delete(String id) async {
    final dbClient = await db;
    return await dbClient.delete(
      tableRecent,
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future<int> deleteAll() async {
    final dbClient = await db;
    return await dbClient.delete(tableRecent, where: '1');
  }

  Future<ImageModel> getImage(String id) async {
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

  Future<List<ImageModel>> getImages({int limit}) async {
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
}
