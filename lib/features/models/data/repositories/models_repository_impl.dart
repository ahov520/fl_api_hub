/// Repository implementation for model pricing aggregation.
///
/// Fans out `/api/pricing` to every enabled account, converts each model row
/// into a [ModelOffer] using the effective-price formula, and groups offers
/// into per-model [ModelComparison]s. Per-account failures are swallowed so
/// one unreachable site never breaks the whole comparison.
library;

import '../../../../core/network/api_request.dart';
import '../../../../core/network/dto/model_pricing_dto.dart';
import '../../../../core/network/proxy_resolver.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/result/result.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/domain/repositories/accounts_repository.dart';
import '../../../settings/domain/entities/global_proxy_setting.dart';
import '../../domain/entities/model_comparison.dart';
import '../../domain/repositories/models_repository.dart';
import '../datasources/models_remote_datasource.dart';

/// new-api base price: 1 unit of `model_ratio` equals \$2 per 1M tokens.
const _kBasePricePerMillionUsd = 2.0;

/// Default [ModelsRepository] implementation.
class ModelsRepositoryImpl implements ModelsRepository {
  final AccountsRepository _accountsRepository;
  final ModelsRemoteDataSource Function(SiteType siteType) _remoteFor;
  final ProxyResolver _proxyResolver;
  final GlobalProxySetting _globalProxy;

  ModelsRepositoryImpl({
    required AccountsRepository accountsRepository,
    required ModelsRemoteDataSource Function(SiteType siteType) remoteFor,
    required ProxyResolver proxyResolver,
    required GlobalProxySetting globalProxy,
  }) : _accountsRepository = accountsRepository,
       _remoteFor = remoteFor,
       _proxyResolver = proxyResolver,
       _globalProxy = globalProxy;

  @override
  Future<Result<List<ModelComparison>>> fetchComparisons() async {
    final accountsResult = await _accountsRepository.getAll();
    final accounts = accountsResult.dataOrNull ?? const <Account>[];
    final enabled = accounts.where((a) => a.enabled).toList();

    final perAccount = await Future.wait(enabled.map(_fetchForAccount));

    // Group every offer by model name.
    final byModel = <String, List<ModelOffer>>{};
    for (var i = 0; i < enabled.length; i++) {
      for (final offer in perAccount[i]) {
        byModel.putIfAbsent(offer.modelName, () => []).add(offer);
      }
    }

    final comparisons = byModel.entries.map((entry) {
      final offers = entry.value
        // Cheapest-first; unpriced offers sink to the bottom.
        ..sort((a, b) {
          if (a.priceUsd == null && b.priceUsd == null) return 0;
          if (a.priceUsd == null) return 1;
          if (b.priceUsd == null) return -1;
          return a.priceUsd!.compareTo(b.priceUsd!);
        });
      return ModelComparison(modelName: entry.key, offers: offers);
    }).toList()..sort((a, b) => a.modelName.compareTo(b.modelName));

    return Success<List<ModelComparison>>(comparisons);
  }

  /// Fetches and converts one account's pricing into offers, returning an
  /// empty list on any failure so a single bad site does not abort the rest.
  Future<List<ModelOffer>> _fetchForAccount(Account account) async {
    final remote = _remoteFor(account.siteType);
    final resolvedProxy = _proxyResolver.resolve(account, _globalProxy);
    final request = ApiRequest(
      baseUrl: account.baseUrl,
      authToken: account.accessToken,
      authType: account.authType,
      userId: account.userId,
      proxy: resolvedProxy,
    );

    final result = await remote.fetchModelPricing(request);
    final pricing = result.dataOrNull;
    if (pricing == null) return const <ModelOffer>[];

    return pricing.models
        .map((dto) => _toOffer(account, dto, pricing.groupRatio))
        .toList();
  }

  /// Converts a pricing row into a [ModelOffer] using the cheapest usable
  /// group ratio available to the account.
  ModelOffer _toOffer(
    Account account,
    ModelPricingDto dto,
    Map<String, double> groupRatio,
  ) {
    final billing = dto.quotaType == QuotaType.perCall
        ? ModelBilling.perCall
        : ModelBilling.token;

    // Pick the enabled group with the lowest ratio that the account can use.
    String? bestGroup;
    double? bestRatio;
    for (final group in dto.enableGroups) {
      final ratio = groupRatio[group];
      if (ratio == null) continue;
      if (bestRatio == null || ratio < bestRatio) {
        bestRatio = ratio;
        bestGroup = group;
      }
    }

    double? priceUsd;
    if (bestRatio != null) {
      priceUsd = billing == ModelBilling.token
          ? dto.modelRatio * bestRatio * _kBasePricePerMillionUsd
          : dto.modelPrice * bestRatio;
    }

    return ModelOffer(
      modelName: dto.modelName,
      accountId: account.id,
      accountName: account.name,
      billing: billing,
      priceUsd: priceUsd,
      group: bestGroup,
      completionRatio: dto.completionRatio,
    );
  }
}
