import 'package:get_it/get_it.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/theme/theme_cubit.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/analytics/data/drift_analytics_repository.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_repository.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/cubit/analytics_cubit.dart';
import 'package:ledgerflow_flutter/features/auth/data/auth_repository_impl.dart';
import 'package:ledgerflow_flutter/features/auth/domain/app_session.dart';
import 'package:ledgerflow_flutter/features/auth/domain/auth_repository.dart';
import 'package:ledgerflow_flutter/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:ledgerflow_flutter/features/sync/data/connectivity_plus_network_connectivity.dart';
import 'package:ledgerflow_flutter/features/sync/data/simulated_remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/sync/data/supabase_remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/sync/data/sync_repository_impl.dart';
import 'package:ledgerflow_flutter/features/sync/domain/network_connectivity.dart';
import 'package:ledgerflow_flutter/features/sync/domain/remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_repository.dart';
import 'package:ledgerflow_flutter/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:ledgerflow_flutter/features/sync/presentation/bloc/sync_inspector_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/data/drift_transaction_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_filter_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_search_bloc.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transactions_cubit.dart';
import 'package:ledgerflow_flutter/features/wallets/data/drift_wallet_repository.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet_repository.dart';
import 'package:ledgerflow_flutter/features/wallets/presentation/cubit/wallets_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt sl = GetIt.instance;

/// Closes registered Blocs/Cubits before closing [AppDatabase].
Future<void> disposeDependencies() async {
  Future<void> closeIfRegistered<T extends Object>(
    Future<void> Function(T instance) disposer,
  ) async {
    if (sl.isRegistered<T>()) {
      await disposer(sl<T>());
    }
  }

  await closeIfRegistered<AnalyticsCubit>((c) => c.close());
  await closeIfRegistered<TransactionsCubit>((c) => c.close());
  await closeIfRegistered<TransactionSearchBloc>((b) => b.close());
  await closeIfRegistered<TransactionFilterCubit>((c) => c.close());
  await closeIfRegistered<WalletsCubit>((c) => c.close());
  await closeIfRegistered<SyncInspectorCubit>((c) => c.close());
  await closeIfRegistered<SyncBloc>((b) => b.close());
  await closeIfRegistered<AuthCubit>((c) => c.close());
  await closeIfRegistered<ThemeCubit>((c) => c.close());

  if (sl.isRegistered<AuthRepository>()) {
    final authRepo = sl<AuthRepository>();
    if (authRepo is AuthRepositoryImpl) {
      await authRepo.dispose();
    }
  }

  await closeIfRegistered<AppDatabase>((db) => db.close());
  await sl.reset(dispose: false);
}

/// Registers core and feature dependencies in [sl].
Future<void> configureDependencies({
  AppConfig? config,
  AppClock? clock,
  AppDatabase? database,
  SupabaseClient? supabaseClient,
  NetworkConnectivity? connectivity,
  RemoteSyncDataSource? simulatedDataSource,
  AppSession initialSession = const SessionUnauthenticated(),
}) async {
  await disposeDependencies();

  final resolvedConfig = config ?? AppConfig.fromEnvironment();
  final resolvedClock = clock ?? const SystemClock();
  final resolvedDb = database ?? AppDatabase();
  if (database != null) {
    await resolvedDb.customSelect('SELECT 1').get();
  }

  sl.registerSingleton<AppConfig>(resolvedConfig);
  sl.registerSingleton<AppClock>(resolvedClock);
  sl.registerSingleton<AppDatabase>(resolvedDb);
  sl.registerLazySingleton<SampleDataSeeder>(
    () => SampleDataSeeder(sl<AppDatabase>(), sl<AppClock>()),
  );

  final resolvedSupabaseClient = supabaseClient ??
      (resolvedConfig.hasSupabaseConfig ? Supabase.instance.client : null);

  sl.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(
      seeder: sl<SampleDataSeeder>(),
      supabaseClient: resolvedSupabaseClient,
      initialSession: initialSession,
    ),
  );

  sl.registerSingleton<NetworkConnectivity>(
    connectivity ?? ConnectivityPlusNetworkConnectivity(),
  );

  sl.registerSingleton<SimulatedRemoteSyncDataSource>(
    (simulatedDataSource as SimulatedRemoteSyncDataSource?) ??
        SimulatedRemoteSyncDataSource(clock: sl<AppClock>()),
  );

  sl.registerSingleton<RemoteSyncDataSource>(
    resolvedSupabaseClient != null
        ? SupabaseRemoteSyncDataSource(
            client: resolvedSupabaseClient,
            clock: sl<AppClock>(),
          )
        : sl<SimulatedRemoteSyncDataSource>(),
  );

  sl.registerSingleton<SyncRepository>(
    SyncRepositoryImpl(
      database: sl<AppDatabase>(),
      cloudDataSource: sl<RemoteSyncDataSource>(),
      simulatedDataSource:
          simulatedDataSource ?? sl<SimulatedRemoteSyncDataSource>(),
      connectivity: sl<NetworkConnectivity>(),
      clock: sl<AppClock>(),
    ),
  );

  sl.registerSingleton<WalletRepository>(
    DriftWalletRepository(
      database: sl<AppDatabase>(),
      clock: sl<AppClock>(),
    ),
  );
  sl.registerSingleton<TransactionRepository>(
    DriftTransactionRepository(
      database: sl<AppDatabase>(),
      clock: sl<AppClock>(),
    ),
  );
  sl.registerSingleton<AnalyticsRepository>(
    DriftAnalyticsRepository(sl<AppDatabase>()),
  );

  sl.registerSingleton<ThemeCubit>(ThemeCubit());
  sl.registerSingleton<AuthCubit>(AuthCubit(sl<AuthRepository>()));
  sl.registerSingleton<SyncBloc>(
    SyncBloc(
      syncRepository: sl<SyncRepository>(),
      authRepository: sl<AuthRepository>(),
      connectivity: sl<NetworkConnectivity>(),
    )..add(const SyncStarted()),
  );
  sl.registerSingleton<SyncInspectorCubit>(
    SyncInspectorCubit(sl<SyncRepository>()),
  );
  sl.registerSingleton<WalletsCubit>(WalletsCubit(sl<WalletRepository>()));
  sl.registerSingleton<TransactionFilterCubit>(TransactionFilterCubit());
  sl.registerSingleton<TransactionSearchBloc>(TransactionSearchBloc());
  sl.registerSingleton<TransactionsCubit>(
    TransactionsCubit(
      transactionRepository: sl<TransactionRepository>(),
      walletRepository: sl<WalletRepository>(),
      filterCubit: sl<TransactionFilterCubit>(),
    ),
  );
  sl.registerSingleton<AnalyticsCubit>(
    AnalyticsCubit(
      repository: sl<AnalyticsRepository>(),
      clock: sl<AppClock>(),
    ),
  );

  if (database != null) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}
