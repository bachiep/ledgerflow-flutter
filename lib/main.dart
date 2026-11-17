import 'package:flutter/material.dart';
import 'package:ledgerflow_flutter/app.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const LedgerFlowApp());
}
