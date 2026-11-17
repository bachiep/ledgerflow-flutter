import 'package:get_it/get_it.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/theme/theme_cubit.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';

final GetIt sl = GetIt.instance;

/// Registers core application dependencies in [sl].
Future<void> configureDependencies({
  AppConfig? config,
  AppClock? clock,
}) async {
  await sl.reset();

  final resolvedConfig = config ?? AppConfig.fromEnvironment();
  final resolvedClock = clock ?? const SystemClock();

  sl.registerSingleton<AppConfig>(resolvedConfig);
  sl.registerSingleton<AppClock>(resolvedClock);
  sl.registerLazySingleton<ThemeCubit>(ThemeCubit.new);
}
