import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/storage/data/datasources/database_helper.dart';
import '../../features/ai/data/repositories/ai_model_repository_impl.dart';
import '../../features/ai/domain/repositories/ai_model_repository.dart';

/// Service locator for dependency injection
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;

  late final SharedPreferences _preferences;
  late final DatabaseHelper _databaseHelper;
  late final String _documentsPath;
  late final String _modelsPath;

  bool _initialized = false;

  /// Initialize all services
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize SharedPreferences
    _preferences = await SharedPreferences.getInstance();

    // Get application directories
    final appDir = await getApplicationDocumentsDirectory();
    _documentsPath = appDir.path;
    _modelsPath = '$_documentsPath/models';

    // Initialize database
    _databaseHelper = DatabaseHelper.instance;
    await _databaseHelper.database;

    _initialized = true;
  }

  /// Get SharedPreferences instance
  SharedPreferences get preferences {
    _checkInitialized();
    return _preferences;
  }

  /// Get DatabaseHelper instance
  DatabaseHelper get databaseHelper {
    _checkInitialized();
    return _databaseHelper;
  }

  /// Get documents directory path
  String get documentsPath {
    _checkInitialized();
    return _documentsPath;
  }

  /// Get models directory path
  String get modelsPath {
    _checkInitialized();
    return _modelsPath;
  }

  /// Create AI model repository
  AiModelRepository createAiModelRepository() {
    _checkInitialized();
    return AiModelRepositoryImpl(modelsPath: _modelsPath);
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError('ServiceLocator not initialized. Call initialize() first.');
    }
  }
}
