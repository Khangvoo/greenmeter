
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:tree_measure_app/src/shared/models/measurement_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'measurements.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE measurements(id INTEGER PRIMARY KEY AUTOINCREMENT, imagePath TEXT, personHeight REAL, treeHeight REAL, latitude REAL, longitude REAL, speciesName TEXT, timestamp TEXT)',
    );
  }

  Future<int> insertMeasurement(Measurement measurement) async {
    Database db = await database;
    return await db.insert('measurements', measurement.toMap());
  }

  Future<List<Measurement>> getMeasurements() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('measurements', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) {
      return Measurement.fromMap(maps[i]);
    });
  }

  Future<int> deleteMeasurement(int id) async {
    Database db = await database;
    return await db.delete(
      'measurements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
