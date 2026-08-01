/// Local data source for announcement read state and caching.
///
/// Read state is stored as a set of announcement ids in the Hive
/// `announcements` box. Cached announcement payloads let the list render
/// instantly on open while a fresh fetch runs in the background.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Box name for announcement storage.
const _boxName = 'announcements';

/// Key for the read-id set within the box.
const _readIdsKey = '__read_ids__';

/// Local persistence for announcement read state.
class AnnouncementsLocalDataSource {
  final Box _box;

  AnnouncementsLocalDataSource(this._box);

  /// Returns the set of announcement ids the user has marked as read.
  Set<String> getReadIds() {
    final raw = _box.get(_readIdsKey);
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  /// Persists the full read-id set.
  Future<void> saveReadIds(Set<String> ids) async {
    await _box.put(_readIdsKey, ids.toList());
  }

  /// Adds a single id to the read set.
  Future<void> markRead(String id) async {
    final ids = getReadIds()..add(id);
    await saveReadIds(ids);
  }

  /// Marks every provided id as read.
  Future<void> markAllRead(Set<String> ids) async {
    final merged = getReadIds()..addAll(ids);
    await saveReadIds(merged);
  }
}

/// Riverpod provider for [AnnouncementsLocalDataSource].
///
/// Requires [initHive] to have been called.
final announcementsLocalDataSourceProvider =
    Provider<AnnouncementsLocalDataSource>((ref) {
      return AnnouncementsLocalDataSource(Hive.box(_boxName));
    });
