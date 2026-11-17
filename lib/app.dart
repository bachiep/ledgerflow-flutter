import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/router/app_router.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/theme/theme_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_filter_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_search_bloc.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transactions_cubit.dart';
import 'package:ledgerflow_flutter/features/wallets/presentation/cubit/wallets_cubit.dart';

class LedgerFlowApp extends StatefulWidget {
  const LedgerFlowApp({super.key, this.router});

  final GoRouter? router;

  @override
  State<LedgerFlowApp> createState() => _LedgerFlowAppState();
}

class _LedgerFlowAppState extends State<LedgerFlowApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = widget.router ?? createAppRouter();
  }

  @override
  void dispose() {
    if (widget.router == null) {
      _router.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
        BlocProvider<WalletsCubit>.value(value: sl<WalletsCubit>()),
        BlocProvider<TransactionFilterCubit>.value(
          value: sl<TransactionFilterCubit>(),
        ),
        BlocProvider<TransactionSearchBloc>.value(
          value: sl<TransactionSearchBloc>(),
        ),
        BlocProvider<TransactionsCubit>.value(value: sl<TransactionsCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'LedgerFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
