import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerflow_flutter/core/theme/theme_cubit.dart';
import 'package:ledgerflow_flutter/core/widgets/state_widgets.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/pages/analytics_page.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/pages/ledger_page.dart';

/// Route paths used across the application.
final class AppRoutes {
  AppRoutes._();

  static const String ledger = '/ledger';
  static const String analytics = '/analytics';
  static const String wallets = '/wallets';
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.ledger,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _HomeScaffoldShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ledger,
                builder: (context, state) => const LedgerPage(),
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
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => context.read<ThemeCubit>().toggleLightDark(),
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
