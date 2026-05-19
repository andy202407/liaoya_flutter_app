import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite 本地数据库服务
/// 负责消息和会话的本地缓存
class DatabaseService {
  static DatabaseService? _instance;
  Database? _database;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'liaoya_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 私聊消息缓存
        await db.execute('''
          CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY,
            friend_id INTEGER NOT NULL,
            data TEXT NOT NULL,
            created_at TEXT,
            UNIQUE(id)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_friend ON messages(friend_id, id DESC)');

        // 群消息缓存
        await db.execute('''
          CREATE TABLE IF NOT EXISTS group_messages (
            id INTEGER PRIMARY KEY,
            group_id INTEGER NOT NULL,
            data TEXT NOT NULL,
            created_at TEXT,
            UNIQUE(id)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_group_messages_group ON group_messages(group_id, id DESC)');

        // 会话列表缓存
        await db.execute('''
          CREATE TABLE IF NOT EXISTS conversations (
            id INTEGER PRIMARY KEY,
            data TEXT NOT NULL,
            last_time TEXT,
            updated_at TEXT
          )
        ''');
      },
    );
  }

  // ===== 私聊消息 =====

  Future<List<Map<String, dynamic>>> getMessages(int friendId, {int limit = 50, int? beforeId}) async {
    final db = await database;
    String where = 'friend_id = ?';
    List<dynamic> args = [friendId];
    if (beforeId != null) {
      where += ' AND id < ?';
      args.add(beforeId);
    }
    final rows = await db.query('messages', where: where, whereArgs: args, orderBy: 'id DESC', limit: limit);
    return rows.map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>).toList().reversed.toList();
  }

  Future<void> insertMessage(int friendId, Map<String, dynamic> message) async {
    final db = await database;
    final id = message['id'] as int?;
    if (id == null) return;
    await db.insert('messages', {
      'id': id,
      'friend_id': friendId,
      'data': jsonEncode(message),
      'created_at': message['created_at'] ?? message['timestamp'] ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearMessages(int friendId) async {
    final db = await database;
    await db.delete('messages', where: 'friend_id = ?', whereArgs: [friendId]);
  }

  // ===== 群消息 =====

  Future<List<Map<String, dynamic>>> getGroupMessages(int groupId, {int limit = 50, int? beforeId}) async {
    final db = await database;
    String where = 'group_id = ?';
    List<dynamic> args = [groupId];
    if (beforeId != null) {
      where += ' AND id < ?';
      args.add(beforeId);
    }
    final rows = await db.query('group_messages', where: where, whereArgs: args, orderBy: 'id DESC', limit: limit);
    return rows.map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>).toList().reversed.toList();
  }

  Future<void> insertGroupMessage(int groupId, Map<String, dynamic> message) async {
    final db = await database;
    final id = message['id'] as int?;
    if (id == null) return;
    await db.insert('group_messages', {
      'id': id,
      'group_id': groupId,
      'data': jsonEncode(message),
      'created_at': message['created_at'] ?? message['timestamp'] ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearGroupMessages(int groupId) async {
    final db = await database;
    await db.delete('group_messages', where: 'group_id = ?', whereArgs: [groupId]);
  }

  // ===== 会话列表 =====

  Future<List<Map<String, dynamic>>> getConversations({int limit = 20}) async {
    final db = await database;
    final rows = await db.query('conversations', orderBy: 'last_time DESC', limit: limit);
    return rows.map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> saveConversations(List<Map<String, dynamic>> conversations) async {
    final db = await database;
    final batch = db.batch();
    for (final conv in conversations) {
      final id = conv['id'] as int?;
      if (id == null) continue;
      batch.insert('conversations', {
        'id': id,
        'data': jsonEncode(conv),
        'last_time': conv['last_time'] ?? '',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateConversationLastMessage(int conversationId, String message, String time) async {
    final db = await database;
    final rows = await db.query('conversations', where: 'id = ?', whereArgs: [conversationId]);
    if (rows.isNotEmpty) {
      final data = jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
      data['last_message'] = message;
      data['last_time'] = time;
      await db.update('conversations', {
        'data': jsonEncode(data),
        'last_time': time,
      }, where: 'id = ?', whereArgs: [conversationId]);
    }
  }

  // 清除所有缓存
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('group_messages');
    await db.delete('conversations');
  }
}
