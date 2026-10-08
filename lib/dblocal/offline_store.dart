import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/member.dart';

class OfflineStore {
  OfflineStore._();
  static final i = OfflineStore._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = p.join(await getDatabasesPath(), 'rts_gym_offline.db');
    _database = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL DEFAULT '',
            phone TEXT NOT NULL DEFAULT '',
            gender TEXT NOT NULL,
            age INTEGER NOT NULL,
            plan TEXT NOT NULL,
            duration_months INTEGER NOT NULL,
            fee REAL NOT NULL,
            joining_date TEXT NOT NULL,
            expiry_date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            notes TEXT NOT NULL DEFAULT '',
            keycard TEXT,
            pr_kg REAL NOT NULL DEFAULT 0,
            photo BLOB,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          "CREATE UNIQUE INDEX members_keycard_unique ON members(keycard) "
          "WHERE keycard IS NOT NULL AND keycard != ''",
        );
        await db.execute('''
          CREATE TABLE finance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER,
            member_name TEXT NOT NULL,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            plan TEXT NOT NULL DEFAULT '',
            description TEXT NOT NULL DEFAULT '',
            paid_at TEXT NOT NULL,
            method TEXT NOT NULL DEFAULT 'Cash',
            FOREIGN KEY(member_id) REFERENCES members(id) ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL DEFAULT '',
            tags TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            FOREIGN KEY(member_id) REFERENCES members(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE checkins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER NOT NULL,
            checked_at TEXT NOT NULL,
            FOREIGN KEY(member_id) REFERENCES members(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        final batch = db.batch();
        batch.insert('settings', {'key': 'revenue_goal', 'value': '18500'});
        for (final plan in kPlans) {
          batch.insert('settings', {
            'key': 'plan_${plan.months}',
            'value': plan.fee.toString(),
          });
        }
        await batch.commit(noResult: true);
      },
    );
    return _database!;
  }
}
