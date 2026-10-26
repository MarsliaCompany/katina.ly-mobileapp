import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class CustomCacheManager extends CacheManager {
  static const key = 'katinaPersistentImageCache';
  static final CustomCacheManager _instance = CustomCacheManager._internal();

  factory CustomCacheManager() => _instance;

  CustomCacheManager._internal()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 2000,
            fileService: HttpFileService(),
            repo: CacheObjectProvider(
              databaseName: key,
              logStatements: false,
            ),
          ),
        );

  static Future<void> ensureInitialized() async {
    await _instance._init();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileSystem = IOFileSystem(directory.path);
    setFileSystem(fileSystem);
  }
}
