/// Maps [UserInfoDto] fields to domain-level [Account] values.
///
/// Does not create a full [Account] (which needs a local ID, timestamps,
/// and user-editable fields like `name` and `enabled`). Instead, it provides
/// extracted values that the repository uses to update an existing account
/// entity after an API sync.
library;

import '../../../../core/network/dto/user_info_dto.dart';

/// Utility class for extracting domain-level values from [UserInfoDto].
class AccountApiMapper {
  const AccountApiMapper._();

  /// Extracts the cached balance from a [UserInfoDto].
  static double? extractBalance(UserInfoDto dto) => dto.balance;

  /// Extracts the display name from a [UserInfoDto].
  static String? extractUsername(UserInfoDto dto) => dto.username;

  /// Extracts the upstream user id from a [UserInfoDto].
  ///
  /// Returns the raw value; callers are responsible for treating
  /// non-positive ids as "unfilled" (the `Account.userId` sentinel).
  static int? extractUserId(UserInfoDto dto) => dto.id;

  /// Extracts the access token if present in the response.
  ///
  /// Some sites (e.g. one-hub) include the access token in the user info
  /// response, which can be used for token resolution.
  static String? extractAccessToken(UserInfoDto dto) => dto.accessToken;

  /// Computes the USD balance from a [UserInfoDto].
  ///
  /// Priority:
  /// 1. If the site explicitly returns `balance` (rare — a few forks do),
  ///    the DTO value is trusted as-is.
  /// 2. Otherwise, derives it as `quota / quotaPerUnit`. In the New API
  ///    family `quota` already represents the *remaining* balance in token
  ///    units, so the historical `used_quota` must NOT be subtracted again.
  ///
  /// Returns `null` when the required inputs are missing or invalid
  /// (e.g. `quota` absent, or `quotaPerUnit <= 0`).
  static double? computeBalance(UserInfoDto dto, double quotaPerUnit) {
    if (dto.balance != null) return dto.balance;
    final quota = dto.quota;
    if (quota == null) return null;
    if (quotaPerUnit <= 0) return null;
    return quota / quotaPerUnit;
  }
}
