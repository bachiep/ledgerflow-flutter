import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/theme/theme_cubit.dart';
import 'package:ledgerflow_flutter/core/widgets/state_widgets.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/pages/analytics_page.dart';
import 'package:ledgerflow_flutter/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:ledgerflow_flutter/features/auth/presentation/pages/welcome_page.dart';
import 'package:ledgerflow_flutter/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/pages/ledger_page.dart';

/// Route paths used across the application.
final class AppRoutes {
  AppRoutes._();

  static const String welcome = '/welcome';
  static const String ledger = '/ledger';
  static const String analytics = '/analytics';
  static const String wallets = '/wallets';
}

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter({AuthCubit? authCubit}) {
  final resolvedAuth = authCubit ?? sl<AuthCubit>();
  final refreshNotifier = _AuthRouterRefresh(resolvedAuth.stream);

  return GoRouter(
    initialLocation: resolvedAuth.state.session.isAuthenticated
        ? AppRoutes.ledger
        : AppRoutes.welcome,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isSignedIn = resolvedAuth.state.session.isAuthenticated;
      final onWelcome = state.matchedLocation == AppRoutes.welcome;

      if (!isSignedIn && !onWelcome) {
        return AppRoutes.welcome;
      }
      if (isSignedIn && onWelcome) {
        return AppRoutes.ledger;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _HomeScaffoldShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ledger,
                builder: (context, state) => LedgerPage(
                  onRefreshSync: () async {
                    context.read<SyncBloc>().add(const SyncRequested());
                  },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analytics,
                builder: (context, state) => AnalyticsPage(
                  onNavigateToLedger: () => context.go(AppRoutes.ledger),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wallets,
                builder: (context, state) => const _SectionPlaceholderPage(
                  title: 'Wallets',
                  icon: Icons.account_balance_wallet_outlined,
                  subtitle: 'Personal and shared wallets will appear here.',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _HomeScaffoldShell extends StatelessWidget {
  const _HomeScaffoldShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LedgerFlow'),
        actions: [
          BlocBuilder<SyncBloc, SyncState>(
            builder: (context, syncState) {
              final icon = syncState is SyncInProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      syncState.simulateOffline
                          ? Icons.cloud_off_outlined
                          : syncState.pendingCount > 0
                              ? Icons.cloud_upload_outlined
                              : Icons.cloud_done_outlined,
                    );
              return IconButton(
                key: const Key('sync_status_button'),
                tooltip: syncState.simulateOffline
                    ? 'Offline simulation active (${syncState.pendingCount} pending)'
                    : 'Sync (${syncState.pendingCount} pending)',
                icon: Badge.count(
                  isLabelVisible: syncState.pendingCount > 0,
                  count: syncState.pendingCount,
                  child: icon,
                ),
                onPressed: () =>
                    context.read<SyncBloc>().add(const SyncRequested()),
              );
            },
          ),
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => context.read<ThemeCubit>().toggleLightDark(),
          ),
          IconButton(
            tooltip: 'Switch account',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallets',
          ),
        ],
      ),
    );
  }
}

class _SectionPlaceholderPage extends StatelessWidget {
  const _SectionPlaceholderPage({
    required this.title,
    required this.icon,
    required this.subtitle,
  });

  final String title;
  final IconData icon;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: icon,
      title: title,
      subtitle: subtitle,
    );
  }
}
