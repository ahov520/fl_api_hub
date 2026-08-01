/// Domain entity for a site announcement.
///
/// Aggregated from every managed account so the user can read all relay
/// site notices in one place. [accountId] / [accountName] identify the
/// source site; [isRead] tracks per-account read state for the unread badge.
library;

/// A single announcement plus its source-account context.
class Announcement {
  /// Stable identity used for read-state persistence.
  ///
  /// Derived from `accountId + title + publishTime` so the same notice
  /// re-fetched later maps to the same id.
  final String id;

  /// Id of the account (site) that published this announcement.
  final String accountId;

  /// Display name of the source site for grouping in the UI.
  final String accountName;

  /// Announcement title (may be empty when the backend only returns a body).
  final String title;

  /// Announcement body (plain text or HTML depending on the backend).
  final String content;

  /// Publish time when known, otherwise `null`.
  final DateTime? publishTime;

  /// Whether the user has marked this announcement as read.
  final bool isRead;

  const Announcement({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.title,
    required this.content,
    this.publishTime,
    this.isRead = false,
  });

  Announcement copyWith({bool? isRead}) {
    return Announcement(
      id: id,
      accountId: accountId,
      accountName: accountName,
      title: title,
      content: content,
      publishTime: publishTime,
      isRead: isRead ?? this.isRead,
    );
  }
}
