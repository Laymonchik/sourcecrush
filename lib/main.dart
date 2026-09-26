import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/audio/sourcecrush_audio_handler.dart';
import 'src/library/likes_controller.dart';
import 'src/library/library_repository.dart';
import 'src/player_controller.dart';
import 'src/ui/app_shell.dart';
import 'src/ui/theme.dart';

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
  final likes = LikesController();

  // Debug builds ship with a few bundled clips so the player can be exercised
  // before the yt-dlp download pipeline is wired up.
  if (kDebugMode) {
    await const LibraryRepository().seedDemoTracks();
  }

  // Likes load on their own: the library scan is asynchronous and can take a
  // while on a large folder, and pruning against a half-built library would
  // delete perfectly good likes.
  await Future.wait([controller.refreshLibrary(), likes.load()]);

  runApp(SourcecrushApp(controller: controller, likes: likes));
}

class SourcecrushApp extends StatelessWidget {
  const SourcecrushApp({
    super.key,
    required this.controller,
    required this.likes,
  });

  final PlayerController controller;
  final LikesController likes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sourcecrush',
      debugShowCheckedModeBanner: false,
      theme: buildSourcecrushTheme(),
      home: AppShell(controller: controller, likes: likes),
    );
  }
}
