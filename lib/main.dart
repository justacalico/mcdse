import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_model.dart';
import 'data/constants.dart';
import 'services/encryption.dart';
import 'services/event_logger.dart';
import 'ui/app_shell.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Runtime encryption key override (MCDSE_SAVE_KEY env var).
  SaveKeys.initFromEnvironment();

  EventLogger.init();

  if (!Platform.environment.containsKey('FLUTTER_TEST') &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1200, 700),
      minimumSize: Size(1200, 490),
      center: true,
      title: Constants.applicationTitle,
    );
    // Don't await waitUntilReadyToShow — in test/headless environments it
    // may never resolve, which would stall startup before runApp().
    unawaited(windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    }));
  }

  runApp(McdseApp(args: args));
}

void unawaited(Future<void> f) {}

class McdseApp extends StatelessWidget {
  const McdseApp({super.key, this.args = const [], this.model});

  final List<String> args;
  final AppModel? model;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Constants.applicationTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
      ),
      home: Scaffold(
        body: AppShell(appModel: model ?? AppModel(), args: args),
      ),
    );
  }
}
