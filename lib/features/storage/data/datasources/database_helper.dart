import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/app_constants.dart';

/// Database helper for local SQLite operations
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper _instance = DatabaseHelper._();
  static DatabaseHelper get instance => _instance;

  Database? _database;

  /// Get database instance
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create summaries table
    await db.execute('''
      CREATE TABLE summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_path TEXT NOT NULL,
        document_name TEXT NOT NULL,
        summary_text TEXT NOT NULL,
        original_length INTEGER,
        summary_length INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create annotations table
    await db.execute('''
      CREATE TABLE annotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_path TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        selected_text TEXT,
        note_text TEXT,
        highlight_color INTEGER NOT NULL,
        start_index INTEGER,
        end_index INTEGER,
        bounds_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create recent_files table
    await db.execute('''
      CREATE TABLE recent_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL UNIQUE,
        file_name TEXT NOT NULL,
        file_type TEXT NOT NULL,
        file_size INTEGER,
        last_opened_at TEXT NOT NULL,
        last_page INTEGER DEFAULT 0,
        total_pages INTEGER
      )
    ''');

    // Create bookmarks table
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_path TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        title TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indices for faster queries
    await db.execute(
        'CREATE INDEX idx_summaries_document ON summaries(document_path)');
    await db.execute(
        'CREATE INDEX idx_annotations_document ON annotations(document_path)');
    await db.execute(
        'CREATE INDEX idx_bookmarks_document ON bookmarks(document_path)');

    // Create page_summaries table
    await db.execute('''
      CREATE TABLE page_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_path TEXT NOT NULL,
        unit_number INTEGER NOT NULL,
        unit_type TEXT NOT NULL,
        summary_text TEXT NOT NULL,
        prompt_template_id TEXT,
        language TEXT DEFAULT 'it',
        created_at TEXT NOT NULL,
        UNIQUE(document_path, unit_number, unit_type)
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_page_summaries_doc ON page_summaries(document_path)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration to version 2: add page_summaries table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS page_summaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_path TEXT NOT NULL,
          unit_number INTEGER NOT NULL,
          unit_type TEXT NOT NULL,
          summary_text TEXT NOT NULL,
          prompt_template_id TEXT,
          language TEXT DEFAULT 'it',
          created_at TEXT NOT NULL,
          UNIQUE(document_path, unit_number, unit_type)
        )
      ''');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_page_summaries_doc ON page_summaries(document_path)');
    }
  }

  /// Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
