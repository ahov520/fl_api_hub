/// Repository implementation for announcement aggregation.
///
/// Fans out a `fetchAnnouncements` call to every enabled account, merges the
/// results, and overlays persisted read state. Per-account failures are
/// swallowed so one unreachable site never breaks the whole list.
library;

import '../../../../core/network/api_request.dart';
import '../../../../core/network/dto/announcement_dto.dart';
import '../../../../core/network/proxy_resolver.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/result/result.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/domain/repositories/accounts_repository.dart';
import '../../../settings/domain/entities/global_proxy_setting.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcements_repository.dart';
import '../datasources/announcements_local_datasource.dart';
import '../datasources/announcements_remote_datasource.dart';

/// Default [AnnouncementsRepository] implementation.
class AnnouncementsRepositoryImpl implements AnnouncementsRepository {
  final AccountsRepository _accountsRepository;
  final AnnouncementsRemoteDataSource Function(SiteType siteType) _remoteFor;
  final AnnouncementsLocalDataSource _local;
  final ProxyResolver _proxyResolver;
  final GlobalProxySetting _globalProxy;

  AnnouncementsRepositoryImpl({
    required AccountsRepository accountsRepository,
    required AnnouncementsRemoteDataSource Function(SiteType siteType)
        remoteFor,
    required AnnouncementsLocalDataSource local,
    required ProxyResolver proxyResolver,
    required GlobalProxySetting globalProxy,
  }) : _accountsRepository = accountsRepository,
       _remoteFor = remoteFor,
       _local = local,
       _proxyResolver = proxyResolver,
       _globalProxy = globalProxy;

  @override
  Future<Result<List<Announcement>>> refreshAll() async {
    final accountsResult = await _accountsRepository.getAll();
    final accounts = accountsResult.dataOrNull ?? const <Account>[];
    final readIds = _local.getReadIds();

    final enabled = accounts.where((a) => a.enabled).toList();

    // Fan out per-account fetches in parallel; each is isolated so a single
    // failure does not abort the others.
    final perAccount = await Future.wait(enabled.map(_fetchForAccount));

    final merged = <Announcement>[];
    for (var i = 0; i < enabled.length; i++) {
      final account = enabled[i];
      for (final dto in perAccount[i]) {
        final id = _announcementId(account.id, dto.title, dto.publishTime);
        merged.add(
          Announcement(
            id: id,
            accountId: account.id,
            accountName: account.name,
            title: dto.title,
            content: dto.content,
            publishTime: dto.publishTime != null
                ? DateTime.fromMillisecondsSinceEpoch(dto.publishTime! * 1000)
                : null,
            isRead: readIds.contains(id),
          ),
        );
      }
    }

    // Newest first; undated announcements sink to the bottom.
    merged.sort((a, b) {
      final at = a.publishTime?.millisecondsSinceEpoch ?? 0;
      final bt = b.publishTime?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });

    return Success<List<Announcement>>(merged);
  }

  /// Fetches announcements for one account, returning an empty list on any
  /// failure so a single bad site does not abort the aggregate.
  Future<List<AnnouncementDto>> _fetchForAccount(Account account) async {
    final remote = _remoteFor(account.siteType);
    final resolvedProxy = _proxyResolver.resolve(account, _globalProxy);
    final request = ApiRequest(
      baseUrl: account.baseUrl,
      authToken: account.accessToken,
      authType: account.authType,
      userId: account.userId,
      proxy: resolvedProxy,
    );
    final result = await remote.fetchAnnouncements(request);
    return result.dataOrNull?.announcements ?? const <AnnouncementDto>[];
  }

  @override
  Future<Result<void>> markRead(String id) async {
    await _local.markRead(id);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> markIdsRead(Set<String> ids) async {
    await _local.markAllRead(ids);
    return const Success<void>(null);
  }

  /// Builds a stable announcement id from its source account and content.
  static String _announcementId(String accountId, String title, int? time) {
    return '$accountId|$title|${time ?? 0}';
  }
}
