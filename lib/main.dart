import 'package:flutter/material.dart';

import 'app.dart';
import 'core/settings/app_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsController.instance.load();
  runApp(const RunnyApp());
}
