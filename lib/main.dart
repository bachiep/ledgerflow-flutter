import 'package:flutter/material.dart';
import 'package:ledgerflow_flutter/app.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.hasSupabaseConfig) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  }
  await configureDependencies(config: config);
  runApp(const LedgerFlowApp());
}
