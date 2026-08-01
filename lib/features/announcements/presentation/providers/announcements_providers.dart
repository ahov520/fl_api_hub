/// Riverpod providers for the Announcements feature.
///
/// Wires [AnnouncementsRepositoryImpl] to its dependencies and exposes the
/// [announcementsProvider] notifier for UI consumption.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/proxy_resolver.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../settings/data/providers/global_proxy_providers.dart';
import '../../data/datasources/announcements_local_datasource.dart';
import '../../data/datasources/announcements_remote_datasource.dart';
import '../../data/repositories/announcements_repository_impl.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcements_repository.dart';
import 'announcements_notifier.dart';

export 'announcements_notifier.dart';

/// Provides the [AnnouncementsRepository] implementation.
final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepositoryImpl(
    accountsRepository: ref.watch(accountsRepositoryProvider),
    remoteFor: (siteType) =>
        ref.watch(announcementsRemoteDataSourceProvider(siteType)),
    local: ref.watch(announcementsLocalDataSourceProvider),
    proxyResolver: ref.watch(proxyResolverProvider),
    globalProxy: ref.watch(currentGlobalProxyProvider),
  );
});

/// Manages the aggregated list of [Announcement] entities.
final announcementsProvider =
    AsyncNotifierProvider<AnnouncementsNotifier, List<Announcement>>(
      AnnouncementsNotifier.new,
    );
