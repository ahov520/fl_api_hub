/// State notifier for the aggregated announcements list.
///
/// Owns the in-memory list, triggers refreshes via the repository, and
/// applies read-state mutations optimistically so the unread badge updates
/// instantly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcements_repository.dart';
import 'announcements_providers.dart';

/// Manages the list of aggregated [Announcement] entities.
class AnnouncementsNotifier extends AsyncNotifier<List<Announcement>> {
  AnnouncementsRepository get _repository =>
      ref.read(announcementsRepositoryProvider);

  @override
  Future<List<Announcement>> build() => _refresh();

  /// Re-fetches announcements from every account.
  Future<List<Announcement>> _refresh() async {
    final result = await _repository.refreshAll();
    return result.dataOrNull ?? const <Announcement>[];
  }

  /// Pull-to-refresh entry point.
  Future<void> refresh() async {
    state = const AsyncLoading<List<Announcement>>().copyWithPrevious(state);
    state = await AsyncValue.guard(_refresh);
  }

  /// Marks a single announcement read, updating state in place.
  Future<void> markRead(String id) async {
    await _repository.markRead(id);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final a in current) a.id == id ? a.copyWith(isRead: true) : a,
    ]);
  }

  /// Marks every currently-loaded announcement read.
  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _repository.markIdsRead(current.map((a) => a.id).toSet());
    state = AsyncData([
      for (final a in current) a.copyWith(isRead: true),
    ]);
  }
}

/// Count of unread announcements for the badge.
final unreadAnnouncementsCountProvider = Provider<int>((ref) {
  final list = ref.watch(announcementsProvider).valueOrNull;
  if (list == null) return 0;
  return list.where((a) => !a.isRead).length;
});
