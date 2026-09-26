import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/audio/sourcecrush_audio_handler.dart';
import 'src/library/library_repository.dart';
import 'src/player_controller.dart';
import 'src/ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // audio_service hosts playback in its own foreground service so audio keeps
  // going when the app is backgrounded and headset buttons keep working.
  final handler = await AudioService.init(
    builder: SourcecrushAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mako.sourcecrush.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  final controller = PlayerController(handler)..attach();

  // Debug builds ship with a few bundled clips so the player can be exercised
  // before the yt-dlp download pipeline is wired up.
  if (kDebugMode) {
    await const LibraryRepository().seedDemoTracks();
  }
  await controller.refreshLibrary();

  runApp(SourcecrushApp(controller: controller));
}

class SourcecrushApp extends StatelessWidget {
  const SourcecrushApp({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sourcecrush',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DDC84),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: AppShell(controller: controller),
    );
  }
}
