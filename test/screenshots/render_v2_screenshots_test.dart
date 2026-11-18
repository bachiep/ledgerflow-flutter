import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/app.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/auth/domain/app_session.dart';
import 'package:ledgerflow_flutter/features/sync/data/connectivity_plus_network_connectivity.dart';
import 'package:ledgerflow_flutter/features/sync/data/simulated_remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transactions_cubit.dart';

const bool _writeScreenshots = bool.fromEnvironment('WRITE_SCREENSHOTS');

Future<void> _loadWindowsFlutterFonts() async {
  if (!Platform.isWindows) {
    return;
  }
  const fontDir = r'C:\src\flutter\bin\cache\artifacts\material_fonts';

  Future<void> loadFamily(String family, List<String> fileNames) async {
    final loader = FontLoader(family);
    var loadedAny = false;
    for (final fileName in fileNames) {
      final file = File('$fontDir\\$fileName');
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
        loadedAny = true;
      }
    }
    if (loadedAny) {
      await loader.load();
    }
  }

  await loadFamily('MaterialIcons', const ['materialicons-regular.otf']);
  const robotoFiles = [
    'roboto-light.ttf',
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-italic.ttf',
  ];
  await loadFamily('Roboto', robotoFiles);
  await loadFamily('Segoe UI', robotoFiles);

  final monoLoader = FontLoader('monospace');
  final consola = File(r'C:\Windows\Fonts\consola.ttf');
  final consolaBold = File(r'C:\Windows\Fonts\consolab.ttf');
  if (consola.existsSync()) {
    monoLoader.addFont(
      Future<ByteData>.value(ByteData.sublistView(consola.readAsBytesSync())),
    );
    if (consolaBold.existsSync()) {
      monoLoader.addFont(
        Future<ByteData>.value(
          ByteData.sublistView(consolaBold.readAsBytesSync()),
        ),
      );
    }
    await monoLoader.load();
  } else {
    await loadFamily('monospace', const ['roboto-regular.ttf', 'roboto-bold.ttf']);
  }
}

Future<void> _seedSixMonthDemoHistory(
  AppDatabase db,
  AppClock clock,
) async {
  final seeder = SampleDataSeeder(db, clock);
  await seeder.seedGuestSampleIfEmpty();

  final historicalMonths = <({
    int month,
    int income,
    int expense,
    String noteIn,
    String noteOut,
  })>[
    (
      month: 6,
      income: 12000000,
      expense: 7800000,
      noteIn: 'June stipend',
      noteOut: 'June living & rent',
    ),
    (
      month: 7,
      income: 13500000,
      expense: 8400000,
      noteIn: 'July stipend',
      noteOut: 'July living & groceries',
    ),
    (
      month: 8,
      income: 15000000,
      expense: 9200000,
      noteIn: 'August stipend & bonus',
      noteOut: 'August rent & utilities',
    ),
    (
      month: 9,
      income: 14200000,
      expense: 8100000,
      noteIn: 'September stipend',
      noteOut: 'September dining & transit',
    ),
  ];

  await db.batch((batch) {
    final rows = <TransactionsCompanion>[];
    for (final item in historicalMonths) {
      final inAt = DateTime.utc(2026, item.month, 10, 9).millisecondsSinceEpoch;
      final outAt =
          DateTime.utc(2026, item.month, 18, 18).millisecondsSinceEpoch;
      rows.addAll([
        TransactionsCompanion.insert(
          id: 'hist-in-${item.month}',
          walletId: SampleDataSeeder.personalWalletId,
          categoryId: SampleDataSeeder.catSalaryId,
          type: 'income',
          amountMinor: item.income,
          note: Value(item.noteIn),
          occurredAtEpochMs: inAt,
          updatedAtEpochMs: inAt,
          syncStatus: const Value('synced'),
        ),
        TransactionsCompanion.insert(
          id: 'hist-out-${item.month}',
          walletId: SampleDataSeeder.personalWalletId,
          categoryId: SampleDataSeeder.catFoodId,
          type: 'expense',
          amountMinor: item.expense,
          note: Value(item.noteOut),
          occurredAtEpochMs: outAt,
          updatedAtEpochMs: outAt,
          syncStatus: const Value('synced'),
        ),
      ]);
    }
    batch.insertAllOnConflictUpdate(db.transactions, rows);
  });
}

Future<void> _capturePng(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String relativePath,
) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final bytes = byteData!.buffer.asUint8List();
    final outFile = File(relativePath);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(bytes);
  });
}

void main() {
  testWidgets(
    'renders v2.0 mobile screenshots when WRITE_SCREENSHOTS=true',
    (WidgetTester tester) async {
      if (!_writeScreenshots) {
        return;
      }

      await tester.runAsync(_loadWindowsFlutterFonts);

      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      tester.view.physicalSize = const Size(786, 1704);
      tester.view.devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
      final clock = FixedClock(DateTime.utc(2026, 11, 18, 9, 0));
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      await tester.runAsync(() async {
        await _seedSixMonthDemoHistory(db, clock);
        await configureDependencies(
          config: const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
          clock: clock,
          database: db,
          connectivity: const AlwaysOnlineNetworkConnectivity(),
          simulatedDataSource: SimulatedRemoteSyncDataSource(
            clock: clock,
            simulatedLatency: Duration.zero,
          ),
          initialSession: const SessionGuest(),
        );
      });
      addTearDown(disposeDependencies);

      final captureKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: const LedgerFlowApp(),
        ),
      );

      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (sl<TransactionsCubit>().state is TransactionsLoaded) {
            break;
          }
        }
      });
      await tester.pumpAndSettle();

      // 1. Ledger v2.0 (Date-grouped daily totals + Swiss Fintech light UI)
      await _capturePng(
        tester,
        captureKey,
        'docs/screenshots/01-ledger-transactions.png',
      );

      // 2. Analytics v2.0 (6-Month Trend + Donut + Budget alerts)
      await tester.tap(find.text('Analytics'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await _capturePng(
        tester,
        captureKey,
        'docs/screenshots/02-analytics-cashflow.png',
      );

      // 5. Offline CSV Statement Export Sheet over Analytics
      await tester.tap(find.byKey(const Key('export_csv_button')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await _capturePng(
        tester,
        captureKey,
        'docs/screenshots/05-csv-budget-sheet.png',
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // 4. Wallets v2.0 in OLED Dark Mode
      await tester.tap(find.byTooltip('Toggle theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wallets'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await _capturePng(
        tester,
        captureKey,
        'docs/screenshots/04-wallets-dark-mode.png',
      );

      // 3. Sync Outbox Inspector with queued offline mutation (Light Mode)
      await tester.tap(find.byTooltip('Toggle theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ledger'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sync_status_button')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('simulate_offline_switch')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_tx_fab')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tx_amount_field')),
        '145000',
      );
      await tester.enterText(
        find.byKey(const Key('tx_note_field')),
        'Grab ride to tech hub',
      );
      await tester.tap(find.byKey(const Key('tx_submit_button')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sync_status_button')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await _capturePng(
        tester,
        captureKey,
        'docs/screenshots/03-sync-outbox-inspector.png',
      );
      } finally {
        debugDisableShadows = previousShadows;
      }
    },
  );
}
