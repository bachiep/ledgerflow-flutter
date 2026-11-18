import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/widgets/state_widgets.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_repository.dart';
import 'package:ledgerflow_flutter/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:ledgerflow_flutter/features/sync/presentation/bloc/sync_inspector_cubit.dart';

class SyncOutboxInspectorSheet extends StatelessWidget {
  const SyncOutboxInspectorSheet({super.key, this.syncRepository});

  final SyncRepository? syncRepository;

  static Future<void> show(BuildContext context, {SyncRepository? repository}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => BlocProvider<SyncBloc>.value(
        value: context.read<SyncBloc>(),
        child: SyncOutboxInspectorSheet(syncRepository: repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = syncRepository;
    if (repo != null) {
      return BlocProvider<SyncInspectorCubit>(
        create: (_) => SyncInspectorCubit(repo),
        child: const _SyncOutboxInspectorBody(),
      );
    }
    return BlocProvider<SyncInspectorCubit>.value(
      value: sl<SyncInspectorCubit>(),
      child: const _SyncOutboxInspectorBody(),
    );
  }
}

class _SyncOutboxInspectorBody extends StatelessWidget {
  const _SyncOutboxInspectorBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sync Outbox Inspector',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BlocBuilder<SyncBloc, SyncState>(
                builder: (context, syncState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        key: const Key('simulate_offline_switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Simulate Offline'),
                        subtitle: const Text(
                          'Keep writes queued in SQLite outbox until reconnected.',
                        ),
                        value: syncState.simulateOffline,
                        onChanged: (enabled) {
                          context
                              .read<SyncBloc>()
                              .add(SimulateOfflineToggled(enabled));
                        },
                      ),
                      const SizedBox(height: 8),
                      _SyncStatusCard(syncState: syncState),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Outbox Queue',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: BlocBuilder<SyncInspectorCubit, SyncInspectorState>(
                  builder: (context, state) {
                    return switch (state) {
                      SyncInspectorLoading() => const LoadingStateWidget(
                          message: 'Loading outbox queue...',
                        ),
                      SyncInspectorError(:final message) => ErrorStateWidget(
                          message: message,
                          onRetry: () =>
                              context.read<SyncInspectorCubit>().start(),
                        ),
                      SyncInspectorEmpty() => const EmptyStateWidget(
                          icon: Icons.cloud_done_outlined,
                          title: 'Outbox is clean',
                          subtitle:
                              'Create, edit, or delete a transaction to watch atomic outbox rows appear here.',
                        ),
                      SyncInspectorLoaded(:final items) => ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) =>
                              _OutboxItemTile(item: items[index]),
                        ),
                    };
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.syncState});

  final SyncState syncState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;
    final isSyncing = syncState is SyncInProgress;

    final (headline, color) = switch (syncState) {
      SyncInProgress() => ('Synchronizing outbox...', theme.colorScheme.primary),
      SyncFailureState(:final message) => (message, colors.failed),
      SyncSuccess(:final summary) => (
          'Synced ${summary.pushedCount} pushed, ${summary.pulledCount} pulled',
          colors.synced,
        ),
      SyncIdle() => (
          syncState.simulateOffline
              ? 'Offline simulation active (${syncState.pendingCount} pending)'
              : '${syncState.pendingCount} pending in outbox',
          syncState.pendingCount > 0 ? colors.pending : colors.synced,
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (syncState.lastSyncedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Last synced: ${DateFormat.Hm().add_MMMd().format(syncState.lastSyncedAt!.toLocal())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('sync_now_button'),
              onPressed: isSyncing
                  ? null
                  : () => context.read<SyncBloc>().add(const SyncRequested()),
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: const Text('Sync Now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutboxItemTile extends StatelessWidget {
  const _OutboxItemTile({required this.item});

  final SyncOutboxItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;

    final (statusText, statusColor) = item.isProcessed
        ? ('SYNCED', colors.synced)
        : item.isFailed
            ? ('FAILED (${item.attempts}x)', colors.failed)
            : ('PENDING', colors.pending);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${item.operation.toUpperCase()} ${item.entityType.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${item.entityId.substring(0, item.entityId.length.clamp(0, 8))} • ${DateFormat.Hm().add_MMMd().format(item.createdAt.toLocal())}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          if (item.lastError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: colors.failed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.lastError!,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.failed),
              ),
            ),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: SelectableText(
              item.payloadJson,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
