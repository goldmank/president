import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const PresidentApp());
}
