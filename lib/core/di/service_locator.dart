import 'package:get_it/get_it.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/theme/theme_cubit.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/analytics/data/drift_analytics_repository.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_repository.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/cubit/analytics_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/data/drift_transaction_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_filter_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_search_bloc.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transactions_cubit.dart';
import 'package:ledgerflow_flutter/features/wallets/data/drift_wallet_repository.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet_repository.dart';
import 'package:ledgerflow_flutter/features/wallets/presentation/cubit/wallets_cubit.dart';

final GetIt sl = GetIt.instance;

/// Registers core and feature dependencies in [sl].
Future<void> configureDependencies({
  AppConfig? config,
  AppClock? clock,
  AppDatabase? database,
}) async {
  await sl.reset();

  final resolvedConfig = config ?? AppConfig.fromEnvironment();
  final resolvedClock = clock ?? const SystemClock();

  sl.registerSingleton<AppConfig>(resolvedConfig);
  sl.registerSingleton<AppClock>(resolvedClock);
  sl.registerLazySingleton<AppDatabase>(
    () => database ?? AppDatabase(),
    dispose: (db) => db.close(),
  );
  sl.registerLazySingleton<SampleDataSeeder>(
    () => SampleDataSeeder(sl<AppDatabase>(), sl<AppClock>()),
  );

  sl.registerLazySingleton<WalletRepository>(
    () => DriftWalletRepository(
      database: sl<AppDatabase>(),
      clock: sl<AppClock>(),
    ),
  );
  sl.registerLazySingleton<TransactionRepository>(
    () => DriftTransactionRepository(
      database: sl<AppDatabase>(),
      clock: sl<AppClock>(),
    ),
  );
  sl.registerLazySingleton<AnalyticsRepository>(
    () => DriftAnalyticsRepository(sl<AppDatabase>()),
  );

  sl.registerLazySingleton<ThemeCubit>(
    ThemeCubit.new,
    dispose: (c) => c.close(),
  );
  sl.registerLazySingleton<WalletsCubit>(
    () => WalletsCubit(sl<WalletRepository>()),
    dispose: (c) => c.close(),
  );
  sl.registerLazySingleton<TransactionFilterCubit>(
    TransactionFilterCubit.new,
    dispose: (c) => c.close(),
  );
  sl.registerLazySingleton<TransactionSearchBloc>(
    TransactionSearchBloc.new,
    dispose: (b) => b.close(),
  );
  sl.registerLazySingleton<TransactionsCubit>(
    () => TransactionsCubit(
      transactionRepository: sl<TransactionRepository>(),
      walletRepository: sl<WalletRepository>(),
      filterCubit: sl<TransactionFilterCubit>(),
    ),
    dispose: (c) => c.close(),
  );
  sl.registerLazySingleton<AnalyticsCubit>(
    () => AnalyticsCubit(
      repository: sl<AnalyticsRepository>(),
      clock: sl<AppClock>(),
    ),
    dispose: (c) => c.close(),
  );
}
