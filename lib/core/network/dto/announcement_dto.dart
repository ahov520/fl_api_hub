/// DTO for site announcement / notice endpoints.
///
/// Different backend families expose announcements differently:
/// - Common/new-api: `GET /api/notice` returns a single notice string or a
///   list of `{ title, content, time }` objects depending on deployment.
/// - Others: not supported yet; adapters return an empty list.
///
/// Normalizes all supported formats to a simple structure for UI consumption.
library;

/// A single announcement published by a relay site.
class AnnouncementDto {
  /// Announcement title (may be empty when the backend only returns a body).
  final String title;

  /// Announcement body (plain text or HTML depending on the backend).
  final String content;

  /// Publish time as a Unix epoch (seconds) when known, otherwise `null`.
  final int? publishTime;

  const AnnouncementDto({
    required this.title,
    required this.content,
    this.publishTime,
  });

  /// Parses a raw JSON map from the Common/new-api notice endpoint.
  ///
  /// new-api historically returns the notice as a single string, but some
  /// deployments return objects with `{ title, content, time }`.
  static AnnouncementDto fromCommonJson(Map<String, dynamic> json) {
    final time = json['time'] ?? json['publish_time'] ?? json['created_at'];
    return AnnouncementDto(
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? json['notice']?.toString() ?? '',
      publishTime: time is num ? time.toInt() : int.tryParse('$time'),
    );
  }

  @override
  String toString() =>
      'AnnouncementDto(title: $title, publishTime: $publishTime)';
}

/// List response for announcements.
class AnnouncementListDto {
  final List<AnnouncementDto> announcements;

  const AnnouncementListDto({required this.announcements});

  const AnnouncementListDto.empty() : announcements = const [];
}
