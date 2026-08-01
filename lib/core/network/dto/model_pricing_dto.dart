/// DTO for the new-api compatible model pricing endpoint.
///
/// Endpoint: `GET /api/pricing`
///
/// Response envelope:
/// ```json
/// {
///   "success": true,
///   "data": [
///     {
///       "model_name": "gpt-4o",
///       "quota_type": 0,
///       "model_ratio": 5.0,
///       "model_price": 0,
///       "completion_ratio": 1.0,
///       "enable_groups": ["default", "vip"]
///     }
///   ],
///   "group_ratio": { "default": 1.0, "vip": 0.8 },
///   "usable_group": { "default": "默认分组" }
/// }
/// ```
///
/// Effective input price per 1M tokens (USD) for token-billed models is
/// `model_ratio * group_ratio * 2` (the new-api `$2 / 1M` base). Per-call
/// models (`quota_type == 1`) bill `model_price * group_ratio` per request.
library;

/// Billing mode for a model.
enum QuotaType {
  /// Billed by token usage (`model_ratio` semantics).
  token,

  /// Billed per request (`model_price` semantics).
  perCall,
}

/// A single model's pricing row.
class ModelPricingDto {
  final String modelName;
  final QuotaType quotaType;

  /// Token billing ratio (only meaningful for [QuotaType.token]).
  final double modelRatio;

  /// Per-call price (only meaningful for [QuotaType.perCall]).
  final double modelPrice;

  /// Output/completion ratio relative to input (informational).
  final double completionRatio;

  /// Groups in which this model is enabled.
  final List<String> enableGroups;

  const ModelPricingDto({
    required this.modelName,
    required this.quotaType,
    required this.modelRatio,
    required this.modelPrice,
    required this.completionRatio,
    required this.enableGroups,
  });

  /// Parses one row of the `/api/pricing` `data` array.
  static ModelPricingDto fromJson(Map<String, dynamic> json) {
    final quotaTypeRaw = json['quota_type'];
    final quotaType = (quotaTypeRaw is num && quotaTypeRaw.toInt() == 1)
        ? QuotaType.perCall
        : QuotaType.token;

    final groups = <String>[];
    final rawGroups = json['enable_groups'];
    if (rawGroups is List) {
      groups.addAll(rawGroups.map((e) => e.toString()));
    }

    return ModelPricingDto(
      modelName: json['model_name']?.toString() ?? '',
      quotaType: quotaType,
      modelRatio: (json['model_ratio'] as num?)?.toDouble() ?? 0,
      modelPrice: (json['model_price'] as num?)?.toDouble() ?? 0,
      completionRatio: (json['completion_ratio'] as num?)?.toDouble() ?? 1,
      enableGroups: groups,
    );
  }
}

/// Full `/api/pricing` response: per-model rows plus group ratio table.
class ModelPricingResponseDto {
  final List<ModelPricingDto> models;

  /// Maps group name → billing multiplier for that group.
  final Map<String, double> groupRatio;

  /// Groups the authenticated user is allowed to use.
  final Map<String, String> usableGroup;

  const ModelPricingResponseDto({
    required this.models,
    required this.groupRatio,
    required this.usableGroup,
  });

  const ModelPricingResponseDto.empty()
    : models = const [],
      groupRatio = const {},
      usableGroup = const {};

  /// Parses the full `/api/pricing` envelope.
  static ModelPricingResponseDto fromEnvelope(Map<String, dynamic> json) {
    final models = <ModelPricingDto>[];
    final data = json['data'];
    if (data is List) {
      for (final row in data) {
        if (row is Map<String, dynamic>) {
          models.add(ModelPricingDto.fromJson(row));
        }
      }
    }

    final groupRatio = <String, double>{};
    final rawRatio = json['group_ratio'];
    if (rawRatio is Map) {
      rawRatio.forEach((key, value) {
        if (value is num) groupRatio[key.toString()] = value.toDouble();
      });
    }

    final usableGroup = <String, String>{};
    final rawUsable = json['usable_group'];
    if (rawUsable is Map) {
      rawUsable.forEach((key, value) {
        usableGroup[key.toString()] = value?.toString() ?? '';
      });
    }

    return ModelPricingResponseDto(
      models: models,
      groupRatio: groupRatio,
      usableGroup: usableGroup,
    );
  }
}
