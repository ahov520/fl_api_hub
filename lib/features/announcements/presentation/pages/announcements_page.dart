/// Aggregated announcements page.
///
/// Lists notices from every enabled account in one place, newest first,
/// with pull-to-refresh, an unread badge, and a "mark all read" action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../providers/announcements_providers.dart';
import '../widgets/announcement_card.dart';

class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(announcementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('站点公告'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: '全部标为已读',
            onPressed: () =>
                ref.read(announcementsProvider.notifier).markAllRead(),
          ),
        ],
      ),
      body: switch (asyncList) {
        AsyncLoading() => const AppLoadingState(message: '正在加载公告…'),
        AsyncError(:final error) => AppErrorState(
          message: '加载公告失败：$error',
          onRetry: () => ref.read(announcementsProvider.notifier).refresh(),
        ),
        AsyncData(:final value) => _buildList(context, ref, value),
        _ => const AppLoadingState(),
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> announcements,
  ) {
    if (announcements.isEmpty) {
      return const AppEmptyState(
        icon: Icons.campaign_outlined,
        message: '暂无公告\n支持公告的站点会在这里聚合展示',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(announcementsProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final a = announcements[index];
          return AnnouncementCard(
            announcement: a,
            onTap: () =>
                ref.read(announcementsProvider.notifier).markRead(a.id),
          );
        },
      ),
    );
  }
}
