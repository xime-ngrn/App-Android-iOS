import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite de metadatos (equivalente multiplataforma a Core Data).
///
/// Esquema normalizado:
///  - albums: categorías creadas por el usuario.
///  - media: un registro por archivo (fecha, ubicación, filtro, duración...).
///  - tags: relación N:M entre media y etiquetas.
class AppDatabase {
  static const _fileName = 'cammic_metadata.db';
  static const _version = 1;

  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) throw StateError('La base de datos no se ha abierto');
    return database;
  }

  Future<void> open() async {
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, _fileName),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE albums(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE media(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        thumb_path TEXT,
        created_at INTEGER NOT NULL,
        latitude REAL,
        longitude REAL,
        album_id INTEGER REFERENCES albums(id) ON DELETE SET NULL,
        duration_ms INTEGER,
        filter TEXT,
        size_bytes INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('''
      CREATE TABLE tags(
        media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
        tag TEXT NOT NULL,
        PRIMARY KEY(media_id, tag)
      )''');
    // Índices para que los filtros de la galería no hagan full scan.
    batch.execute('CREATE INDEX idx_media_created ON media(created_at DESC)');
    batch.execute('CREATE INDEX idx_media_album ON media(album_id)');
    batch.execute('CREATE INDEX idx_media_type ON media(type)');
    batch.execute('CREATE INDEX idx_tags_tag ON tags(tag)');
    await batch.commit(noResult: true);
  }
}
