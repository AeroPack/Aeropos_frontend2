import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'package:drift/drift.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  final AppDatabase _database;

  DeviceIdService(this._database);

  String? _cachedDeviceId;

  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    String deviceId;

    if (kIsWeb) {
      deviceId = await _generateDeviceId();
      _cachedDeviceId = deviceId;
      return deviceId;
    }

    try {
      final record = await (_database.select(
        _database.syncMetadata,
      )..where((t) => t.key.equals(_deviceIdKey))).getSingleOrNull();

      if (record == null || record.value == null) {
        deviceId = await _generateDeviceId();
        await _database
            .into(_database.syncMetadata)
            .insertOnConflictUpdate(
              SyncMetadataCompanion(
                key: const Value(_deviceIdKey),
                value: Value(deviceId),
                updatedAt: Value(DateTime.now()),
              ),
            );
      } else {
        deviceId = record.value!;
      }
    } catch (e) {
      deviceId = await _generateDeviceId();
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  Future<String> _generateDeviceId() async {
    try {
      String prefix;
      if (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows ||
          Platform.isLinux) {
        final hostname = Platform.localHostname;
        final cleaned = hostname.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        prefix = cleaned.isEmpty
            ? 'DEV'
            : cleaned.toUpperCase().substring(
                  0,
                  cleaned.length >= 4 ? 4 : cleaned.length,
                );
      } else {
        prefix = 'WEB';
      }

      final uuid = const Uuid();
      final suffix = uuid.v4().substring(0, 4).toUpperCase();

      return '$prefix$suffix';
    } catch (e) {
      final uuid = const Uuid();
      final suffix = uuid.v4().substring(0, 5).toUpperCase();
      return 'DEV$suffix';
    }
  }

  Future<void> resetDeviceId() async {
    await (_database.delete(
      _database.syncMetadata,
    )..where((t) => t.key.equals(_deviceIdKey))).go();
    _cachedDeviceId = null;
  }
}