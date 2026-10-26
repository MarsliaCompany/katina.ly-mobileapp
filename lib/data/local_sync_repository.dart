import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:inspireui/utils/logs.dart';

import 'boxes.dart';

class SyncSnapshot<T> {
  const SyncSnapshot({
    required this.data,
    required this.fingerprint,
    required this.updatedAt,
  });

  final T data;
  final String? fingerprint;
  final DateTime? updatedAt;

  Duration? get age =>
      updatedAt == null ? null : DateTime.now().difference(updatedAt!);
}

class LocalSyncKeys {
  static String products({
    List<String>? categories,
    List<String>? tags,
    List<String>? brands,
    List<String>? includes,
    String? search,
    Map<String, dynamic>? attributes,
    String? orderBy,
    String? order,
    String? listingLocation,
    num? minPrice,
    num? maxPrice,
    bool? featured,
    bool? onSale,
    String? page,
  }) {
    final buffer = StringBuffer('products');
    void writeSegment(String prefix, String? value) {
      if (value == null || value.isEmpty) {
        return;
      }
      buffer
        ..write('_')
        ..write(prefix)
        ..write('_')
        ..write(value);
    }

    if (categories != null && categories.isNotEmpty) {
      writeSegment('c', categories.join('-'));
    }
    if (tags != null && tags.isNotEmpty) {
      writeSegment('t', tags.join('-'));
    }
    if (brands != null && brands.isNotEmpty) {
      writeSegment('b', brands.join('-'));
    }
    if (includes != null && includes.isNotEmpty) {
      writeSegment('i', includes.join('-'));
    }
    if (search != null && search.isNotEmpty) {
      writeSegment('s', search.hashCode.toString());
    }
    if (attributes != null && attributes.isNotEmpty) {
      writeSegment('a', attributes.hashCode.toString());
    }
    writeSegment('ob', orderBy);
    writeSegment('or', order);
    writeSegment('loc', listingLocation);
    writeSegment('min', minPrice?.toString());
    writeSegment('max', maxPrice?.toString());
    writeSegment('feat', featured == null ? null : featured.toString());
    writeSegment('sale', onSale == null ? null : onSale.toString());
    writeSegment('p', page);
    return buffer.toString();
  }

  static String filterAttributes({
    String? categoryIds,
    String? tagIds,
    String? brandIds,
  }) {
    final buffer = StringBuffer('filter_attributes');
    void writeSegment(String prefix, String? value) {
      if (value == null || value.isEmpty) {
        return;
      }
      buffer
        ..write('_')
        ..write(prefix)
        ..write('_')
        ..write(value);
    }

    writeSegment('c', categoryIds);
    writeSegment('t', tagIds);
    writeSegment('b', brandIds);
    return buffer.toString();
  }
}

class LocalSyncRepository {
  LocalSyncRepository._internal();

  static final LocalSyncRepository _instance = LocalSyncRepository._internal();

  factory LocalSyncRepository() => _instance;

  static const _version = '_v1';
  static const _syncPrefix = 'sync_';
  static const _hashPrefix = 'hash_';
  static const _timestampPrefix = 'timestamp_';

  final CacheBox _cacheBox = CacheBox();

  Box get _box => _cacheBox.box;

  SyncSnapshot<T>? readSnapshot<T>(
    String key,
    T Function(dynamic raw) parser,
  ) {
    try {
      final rawData = _box.get(_composeKey(_syncPrefix, key));
      if (rawData == null) {
        return null;
      }
      final fingerprint = _box.get(_composeKey(_hashPrefix, key)) as String?;
      final timestamp = _readTimestamp(key);
      final parsedData = parser(rawData);
      return SyncSnapshot<T>(
        data: parsedData,
        fingerprint: fingerprint,
        updatedAt: timestamp,
      );
    } catch (err, trace) {
      printError('[LocalSyncRepository] Failed to read snapshot for $key');
      printError(err, trace);
      unawaited(clear(key));
      return null;
    }
  }

  Future<void> writeSnapshot(
    String key,
    dynamic rawData, {
    required String fingerprint,
    DateTime? updatedAt,
  }) async {
    final timestamp = (updatedAt ?? DateTime.now()).millisecondsSinceEpoch;
    await Future.wait([
      _box.put(_composeKey(_syncPrefix, key), rawData),
      _box.put(_composeKey(_hashPrefix, key), fingerprint),
      _box.put(_composeKey(_timestampPrefix, key), timestamp),
    ]);
  }

  String? readFingerprint(String key) {
    return _box.get(_composeKey(_hashPrefix, key)) as String?;
  }

  Duration? ageOf(String key) {
    final updatedAt = _readTimestamp(key);
    if (updatedAt == null) {
      return null;
    }
    return DateTime.now().difference(updatedAt);
  }

  Future<void> clear(String key) async {
    await Future.wait([
      _box.delete(_composeKey(_syncPrefix, key)),
      _box.delete(_composeKey(_hashPrefix, key)),
      _box.delete(_composeKey(_timestampPrefix, key)),
    ]);
  }

  DateTime? _readTimestamp(String key) {
    final rawTimestamp = _box.get(_composeKey(_timestampPrefix, key));
    if (rawTimestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    }
    return null;
  }

  String _composeKey(String prefix, String key) {
    final sanitizedKey = key.trim().toLowerCase();
    return '$prefix$sanitizedKey$_version';
  }
}
