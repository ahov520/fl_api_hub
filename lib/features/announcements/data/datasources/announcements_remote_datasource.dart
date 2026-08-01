/// Remote data source for announcement operations.
///
/// Thin delegation layer that forwards calls to the appropriate [SiteAdapter],
/// mirroring [AccountsRemoteDataSource]. Errors propagate as [Result.failure]
/// from the adapter layer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_request.dart';
import '../../../../core/network/dto/announcement_dto.dart';
import '../../../../core/network/site_adapter.dart';
import '../../../../core/network/site_adapter_provider.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/result/result.dart';

/// Remote data source for announcement operations.
class AnnouncementsRemoteDataSource {
  final SiteAdapter _adapter;

  AnnouncementsRemoteDataSource(this._adapter);

  /// Fetches announcements for a single account via its site adapter.
  Future<Result<AnnouncementListDto>> fetchAnnouncements(ApiRequest request) =>
      _adapter.fetchAnnouncements(request);
}

/// Provider for [AnnouncementsRemoteDataSource], parameterized by [SiteType].
final announcementsRemoteDataSourceProvider =
    Provider.family<AnnouncementsRemoteDataSource, SiteType>((ref, siteType) {
      final adapter = ref.watch(siteAdapterForTypeProvider(siteType));
      return AnnouncementsRemoteDataSource(adapter);
    });
