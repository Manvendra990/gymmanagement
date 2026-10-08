import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models/member.dart';
import '../dblocal/offline_store.dart';

class AppDb {
  AppDb._();
  static final i = AppDb._();

  static const demoEmail = 'demo@gmail.com';
  static const demoPassword = '123456';
  static const defaultAppName = 'RTS GYM MANAGEMENT';

  final tick = ValueNotifier<int>(0);
  void notifyChanged() => tick.value++;

  String get baseUrl => ApiConfig.baseUrl;

  Future<dynamic> _get(String path) => ApiClient.i.get(path);
  Future<dynamic> _send(String method, String path, [Object? body]) =>
      ApiClient.i.request(method, path, body: body);

  Future<bool> get isOffline async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('account_type') == 'offline';
  }

  String _appNameKey(SharedPreferences prefs) =>
      'app_name_${prefs.getString('admin_id') ?? 'default'}';

  Future<String> appName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appNameKey(prefs)) ?? defaultAppName;
  }

  Future<void> setAppName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('App name cannot be empty.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appNameKey(prefs), trimmed);
    notifyChanged();
  }

  Future<Database> get _local async => OfflineStore.i.database;

  Map<String, Object?> _map(dynamic value) =>
      Map<String, Object?>.from(value as Map);

  Map<String, Object?> _memberMap(dynamic value) {
    final member = _map(value);
    final photo = member['photo'];
    if (photo is String && photo.isNotEmpty) {
      member['photo'] = base64Decode(photo);
    } else {
      member['photo'] = null;
    }
    return member;
  }

  Member _localMember(Map<String, Object?> row) => Member.fromMap(row);

  Future<Map<String, Object?>?> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    if (normalizedEmail == demoEmail && password == demoPassword) {
      await OfflineStore.i.database;
      await prefs.remove('api_token');
      await prefs.setString('account_type', 'offline');
      return {
        'id': 0,
        'name': 'Demo Coach',
        'email': demoEmail,
        'phone': '',
        'type': 'offline',
      };
    }

    final data = _map(
      await _send('POST', '/auth/login', {
        'email': normalizedEmail,
        'password': password,
      }),
    );
    final user = _map(data['user']);
    final type = user['type'];
    if (type != 'online' && type != 'offline') {
      throw StateError('The server returned an invalid account type.');
    }

    await prefs.setString('account_type', type as String);
    if (type == 'offline') {
      await prefs.remove('api_token');
      await OfflineStore.i.database;
    } else {
      await prefs.setString('api_token', data['token'] as String);
    }
    return user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    await prefs.remove('account_type');
    await prefs.remove('admin_name');
    await prefs.remove('admin_email');
    await prefs.remove('admin_id');
    await prefs.remove('admin_phone');
    await prefs.setBool('login', false);
  }

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('login') == false) return false;
    if (prefs.getString('account_type') == 'offline') return true;
    return (prefs.getString('api_token') ?? '').isNotEmpty;
  }

  Future<Map<String, Object?>> currentAdmin() async {
    if (await isOffline) {
      final prefs = await SharedPreferences.getInstance();
      return {
        'id': int.tryParse(prefs.getString('admin_id') ?? '') ?? 0,
        'name': prefs.getString('admin_name') ?? 'Demo Coach',
        'email': prefs.getString('admin_email') ?? demoEmail,
        'phone': prefs.getString('admin_phone') ?? '',
        'type': 'offline',
      };
    }
    return _map(await _get('/auth/profile'));
  }

  Future<void> updateAdminName(String name) async {
    final trimmed = name.trim();
    if (await isOffline) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_name', trimmed);
    } else {
      final admin = _map(
        await _send('PATCH', '/auth/profile', {'name': trimmed}),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'admin_name',
        (admin['name'] as String?) ?? trimmed,
      );
    }
    notifyChanged();
  }

  Future<void> changeAdminPassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (await isOffline) {
      throw StateError(
        'Password changes are unavailable for the offline demo account.',
      );
    }
    await _send('PUT', '/auth/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<List<Member>> members() async {
    if (await isOffline) {
      final rows = await (await _local).query(
        'members',
        orderBy: 'name COLLATE NOCASE',
      );
      return rows.map(_localMember).toList();
    }
    return ((await _get('/members')) as List)
        .map((value) => Member.fromMap(_memberMap(value)))
        .toList();
  }

  Future<Member?> member(int id) async {
    if (await isOffline) {
      final rows = await (await _local).query(
        'members',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : _localMember(rows.first);
    }
    try {
      return Member.fromMap(_memberMap(await _get('/members/$id')));
    } catch (_) {
      return null;
    }
  }

  Future<bool> keycardTaken(String code, {int? exceptMemberId}) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    if (await isOffline) {
      final rows = await (await _local).query(
        'members',
        columns: ['id'],
        where: 'keycard = ?${exceptMemberId == null ? '' : ' AND id != ?'}',
        whereArgs: [trimmed, if (exceptMemberId != null) exceptMemberId],
        limit: 1,
      );
      return rows.isNotEmpty;
    }
    final query =
        '?code=${Uri.encodeQueryComponent(trimmed)}${exceptMemberId == null ? '' : '&except=$exceptMemberId'}';
    return (await _get('/members/keycard/check$query'))['taken'] == true;
  }

  Map<String, Object?> _memberBody(Member member) {
    final body = member.toMap();
    body.remove('id');
    body.remove('photo');
    return body;
  }

  Map<String, Object?> _localMemberBody(Member member) =>
      member.toMap()..remove('id');

  Future<int> addMember(Member member, {String method = 'Cash'}) async {
    if (await isOffline) {
      final db = await _local;
      return db.transaction((txn) async {
        final id = await txn.insert('members', _localMemberBody(member));
        await _insertPayment(
          txn,
          memberId: id,
          memberName: member.name,
          amount: member.fee,
          type: 'joining',
          plan: member.plan,
          description: 'Initial membership payment',
          method: method,
        );
        notifyChanged();
        return id;
      });
    }
    final body = _memberBody(member)..['method'] = method;
    final result = await _send('POST', '/members', body);
    final id = (result['id'] as num).toInt();
    if (member.photo != null && member.photo!.isNotEmpty) {
      await setPhoto(id, member.photo!);
    }
    notifyChanged();
    return id;
  }

  Future<void> updateMember(Member member) async {
    if (member.id == null) throw ArgumentError('Member ID required');
    if (await isOffline) {
      final body = _localMemberBody(member);
      await (await _local).update(
        'members',
        body,
        where: 'id = ?',
        whereArgs: [member.id],
      );
    } else {
      await _send('PUT', '/members/${member.id}', _memberBody(member));
    }
    notifyChanged();
  }

  Future<void> renew(
    Member member,
    String plan,
    int months,
    double amount, {
    String method = 'Cash',
  }) async {
    if (await isOffline) {
      final db = await _local;
      await db.transaction((txn) async {
        final start = member.expiryDate.isAfter(DateTime.now())
            ? member.expiryDate
            : DateTime.now();
        final expiry = addMonths(start, months);
        await txn.update(
          'members',
          {
            'plan': plan,
            'duration_months': months,
            'fee': amount,
            'expiry_date': expiry.toIso8601String(),
            'status': 'active',
          },
          where: 'id = ?',
          whereArgs: [member.id],
        );
        await _insertPayment(
          txn,
          memberId: member.id!,
          memberName: member.name,
          amount: amount,
          type: 'renewal',
          plan: plan,
          description: 'Membership renewal ($months month)',
          method: method,
        );
      });
    } else {
      await _send('POST', '/members/${member.id}/renew', {
        'plan': plan,
        'months': months,
        'amount': amount,
        'method': method,
      });
    }
    notifyChanged();
  }

  Future<void> addAdjustment(
    Member member,
    double amount,
    String note, {
    String method = 'Cash',
  }) async {
    if (await isOffline) {
      await _insertPayment(
        await _local,
        memberId: member.id!,
        memberName: member.name,
        amount: amount,
        type: 'adjustment',
        plan: member.plan,
        description: note.isEmpty ? 'Payment adjustment' : note,
        method: method,
      );
    } else {
      await _send('POST', '/members/${member.id}/adjustment', {
        'amount': amount,
        'note': note,
        'method': method,
      });
    }
    notifyChanged();
  }

  Future<void> setStatus(int id, bool active) async {
    if (await isOffline) {
      await (await _local).update(
        'members',
        {'status': active ? 'active' : 'inactive'},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await _send('PATCH', '/members/$id/status', {'active': active});
    }
    notifyChanged();
  }

  Future<void> setPr(int id, double kg) async {
    if (await isOffline) {
      await (await _local).update(
        'members',
        {'pr_kg': kg},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await _send('PATCH', '/members/$id/pr', {'kg': kg});
    }
    notifyChanged();
  }

  Future<void> setPhoto(int id, Uint8List bytes) async {
    if (await isOffline) {
      await (await _local).update(
        'members',
        {'photo': bytes},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await ApiClient.i.uploadBytes(
        '/members/$id/photo',
        'photo',
        bytes,
        filename: 'member_$id.jpg',
      );
    }
    notifyChanged();
  }

  Future<void> deleteMember(int id) async {
    if (await isOffline) {
      await (await _local).delete('members', where: 'id = ?', whereArgs: [id]);
    } else {
      await _send('DELETE', '/members/$id');
    }
    notifyChanged();
  }

  Future<int> cleanInactive() async {
    late int deleted;
    if (await isOffline) {
      final db = await _local;
      deleted = await db.transaction((txn) async {
        final result = await txn.delete(
          'members',
          where: "status = 'inactive'",
        );
        return result;
      });
    } else {
      final result = await _send('DELETE', '/members/inactive/clean');
      deleted = (result['deleted'] as num).toInt();
    }
    notifyChanged();
    return deleted;
  }

  Future<void> _insertPayment(
    DatabaseExecutor db, {
    required int memberId,
    required String memberName,
    required double amount,
    required String type,
    required String plan,
    required String description,
    required String method,
  }) async {
    await db.insert('finance', {
      'member_id': memberId,
      'member_name': memberName,
      'amount': amount,
      'type': type,
      'plan': plan,
      'description': description,
      'paid_at': DateTime.now().toIso8601String(),
      'method': method,
    });
  }

  Future<List<Payment>> payments() async {
    if (await isOffline) {
      final rows = await (await _local).query(
        'finance',
        orderBy: 'paid_at DESC',
      );
      return rows.map((row) => Payment.fromMap(row)).toList();
    }
    return ((await _get('/finance')) as List)
        .map((value) => Payment.fromMap(_map(value)))
        .toList();
  }

  Future<List<Payment>> paymentsFor(int memberId) async {
    if (await isOffline) {
      final rows = await (await _local).query(
        'finance',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'paid_at DESC',
      );
      return rows.map((row) => Payment.fromMap(row)).toList();
    }
    return ((await _get('/finance?member_id=$memberId')) as List)
        .map((value) => Payment.fromMap(_map(value)))
        .toList();
  }

  Future<double> goal() async {
    if (await isOffline) {
      final rows = await (await _local).query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['revenue_goal'],
      );
      if (rows.isEmpty) throw StateError('Offline revenue goal is missing.');
      return double.parse(rows.first['value'] as String);
    }
    return ((await _get('/settings'))['revenue_goal'] as num).toDouble();
  }

  Future<void> setGoal(double value) async {
    if (await isOffline) {
      await (await _local).insert('settings', {
        'key': 'revenue_goal',
        'value': value.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await _send('PUT', '/settings/goal', {'value': value});
    }
    notifyChanged();
  }

  Future<List<PlanOption>> plans() async {
    if (await isOffline) {
      final rows = await (await _local).query(
        'settings',
        where: "key LIKE 'plan_%'",
        orderBy: 'CAST(SUBSTR(key, 6) AS INTEGER)',
      );
      return rows
          .map(
            (row) => PlanOption.of(
              int.parse((row['key'] as String).substring(5)),
              double.parse(row['value'] as String),
            ),
          )
          .toList();
    }
    final result = await _get('/settings');
    return (result['plans'] as List)
        .map(
          (value) => PlanOption.of(
            (value['months'] as num).toInt(),
            (value['fee'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<void> setPlans(List<PlanOption> list) async {
    if (await isOffline) {
      final db = await _local;
      await db.transaction((txn) async {
        await txn.delete('settings', where: "key LIKE 'plan_%'");
        final batch = txn.batch();
        for (final plan in list) {
          batch.insert('settings', {
            'key': 'plan_${plan.months}',
            'value': plan.fee.toString(),
          });
        }
        await batch.commit(noResult: true);
      });
    } else {
      await _send('PUT', '/settings/plans', {
        'plans': list
            .map((plan) => {'months': plan.months, 'fee': plan.fee})
            .toList(),
      });
    }
    notifyChanged();
  }

  Future<List<Note>> notesFor(int memberId) async {
    if (await isOffline) {
      final rows = await (await _local).query(
        'notes',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'created_at DESC',
      );
      return rows.map((row) => Note.fromMap(row)).toList();
    }
    return ((await _get('/members/$memberId/notes')) as List)
        .map((value) => Note.fromMap(_map(value)))
        .toList();
  }

  Future<void> addNote(
    int memberId,
    String title,
    String body,
    String tags,
  ) async {
    if (await isOffline) {
      await (await _local).insert('notes', {
        'member_id': memberId,
        'title': title,
        'body': body,
        'tags': tags,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      await _send('POST', '/members/$memberId/notes', {
        'title': title,
        'body': body,
        'tags': tags,
      });
    }
    notifyChanged();
  }

  Future<Member?> findByCode(String raw) async {
    if (await isOffline) {
      final db = await _local;
      final code = raw.trim();
      var rows = await db.query(
        'members',
        where: 'keycard = ?',
        whereArgs: [code],
        limit: 1,
      );
      if (rows.isEmpty) {
        final match = RegExp(
          r'^(?:mv-?)?0*(\d+)$',
          caseSensitive: false,
        ).firstMatch(code);
        if (match != null) {
          rows = await db.query(
            'members',
            where: 'id = ?',
            whereArgs: [int.parse(match.group(1)!)],
            limit: 1,
          );
        }
      }
      if (rows.isEmpty) {
        rows = await db.query(
          'members',
          where: 'phone = ?',
          whereArgs: [code],
          limit: 1,
        );
      }
      return rows.isEmpty ? null : _localMember(rows.first);
    }
    final result = await _get(
      '/checkins/find?code=${Uri.encodeQueryComponent(raw.trim())}',
    );
    return result == null ? null : Member.fromMap(_memberMap(result));
  }

  Future<bool> checkIn(int memberId) async {
    if (await isOffline) {
      final db = await _local;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toIso8601String();
      final existing = await db.query(
        'checkins',
        columns: ['id'],
        where: 'member_id = ? AND checked_at >= ?',
        whereArgs: [memberId, today],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
      await db.insert('checkins', {
        'member_id': memberId,
        'checked_at': now.toIso8601String(),
      });
      notifyChanged();
      return true;
    }
    final result = await _send('POST', '/checkins/$memberId');
    notifyChanged();
    return result['created'] == true;
  }

  Future<({int total, int streak})> checkinStats(int memberId) async {
    if (await isOffline) {
      final rows = await (await _local).query(
        'checkins',
        columns: ['checked_at'],
        where: 'member_id = ?',
        whereArgs: [memberId],
      );
      final days = rows
          .map((row) => dayOnly(DateTime.parse(row['checked_at'] as String)))
          .toSet();
      var current = dayOnly(DateTime.now());
      if (!days.contains(current))
        current = current.subtract(const Duration(days: 1));
      var streak = 0;
      while (days.contains(current)) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      }
      return (total: rows.length, streak: streak);
    }
    final result = await _get('/checkins/$memberId/stats');
    return (
      total: (result['total'] as num).toInt(),
      streak: (result['streak'] as num).toInt(),
    );
  }

  Future<List<Map<String, Object?>>> todayCheckins() async {
    if (await isOffline) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toIso8601String();
      final rows = await (await _local).rawQuery(
        '''
        SELECT checkins.checked_at AS at, members.name AS name, members.id AS id
        FROM checkins JOIN members ON members.id = checkins.member_id
        WHERE checkins.checked_at >= ?
        ORDER BY checkins.checked_at DESC
        ''',
        [today],
      );
      return rows;
    }
    return ((await _get('/checkins/today/list')) as List)
        .map((value) => _map(value))
        .toList();
  }
}
