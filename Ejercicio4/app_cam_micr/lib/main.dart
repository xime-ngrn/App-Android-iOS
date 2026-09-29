import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/permissions/permission_service.dart';
import 'data/datasources/app_database.dart';
import 'data/datasources/file_storage.dart';
import 'data/repositories/media_repository_impl.dart';
import 'data/services/location_service.dart';
import 'data/services/thumbnail_service.dart';
import 'domain/repositories/media_repository.dart';
import 'domain/usecases/media_usecases.dart';
import 'presentation/app.dart';
import 'presentation/providers/audio_recorder_provider.dart';
import 'presentation/providers/gallery_provider.dart';
import 'presentation/providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- Composición de dependencias (inyección manual) ----
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsProvider(prefs);

  final storage = FileStorage();
  await storage.init();
  final database = AppDatabase();
  await database.open();

  final thumbnails = ThumbnailService(storage);
  final location = LocationService(isEnabled: () => settings.saveLocation);

  final MediaRepository repository = MediaRepositoryImpl(
    database: database,
    storage: storage,
    thumbnails: thumbnails,
    location: location,
  );
  final useCases = MediaUseCases(repository);
  final permissions = PermissionService();

  runApp(
    MultiProvider(
      providers: [
        Provider<PermissionService>.value(value: permissions),
        Provider<ThumbnailService>.value(value: thumbnails),
        Provider<MediaUseCases>.value(value: useCases),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider(create: (_) => GalleryProvider(useCases)..load()),
        ChangeNotifierProvider(create: (_) => AudioRecorderProvider(permissions, useCases)),
      ],
      child: const CamMicApp(),
    ),
  );
}
