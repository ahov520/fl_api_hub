/// Repository contract for site announcement operations.
///
/// Aggregates announcements from all managed accounts and tracks per-account
/// read state. All methods return [Result] to enforce explicit error handling.
library;

import '../../../../core/result/result.dart';
import '../entities/announcement.dart';

/// Abstract repository for announcement aggregation and read state.
abstract class AnnouncementsRepository {
  /// Fetches fresh announcements from every managed account and merges them
  /// with persisted read state. Accounts that fail or are unsupported are
  /// skipped silently so one bad site does not break the whole list.
  Future<Result<List<Announcement>>> refreshAll();

  /// Marks a single announcement as read by its [id].
  Future<Result<void>> markRead(String id);

  /// Marks every announcement whose id is in [ids] as read.
  ///
  /// The notifier passes the currently-known ids so persistence stays in the
  /// data layer without the repository needing to track the live list.
  Future<Result<void>> markIdsRead(Set<String> ids);
}
