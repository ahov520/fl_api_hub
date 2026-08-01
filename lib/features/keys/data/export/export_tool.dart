/// Export tool abstraction with platform filtering.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Supported export channel types.
enum ChannelType {
  openai('OpenAI'),
  anthropic('Anthropic'),
  gemini('Gemini');

  const ChannelType(this.label);
  final String label;
}

/// Configuration for an export operation.
class ExportConfig {
  final ChannelType channelType;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String homepage;

  const ExportConfig({
    required this.channelType,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    this.homepage = '',
  });

  /// Endpoint URL: only OpenAI channel appends /v1.
  String get endpointUrl =>
      channelType == ChannelType.openai ? '$baseUrl/v1' : baseUrl;
}

/// Abstract export tool with platform awareness.
abstract class ExportTool {
  const ExportTool();

  /// Display name of the tool.
  String get name;

  /// Icon for the tool chip.
  IconData get icon;

  /// Platforms this tool supports.
  List<TargetPlatform> get supportedPlatforms;

  /// Whether [export] launches an external deeplink (true) or returns text to
  /// copy to the clipboard (false). Deeplink tools handle their own UX.
  bool get isDeeplink => false;

  /// Whether this tool supports the current platform.
  bool get supportsCurrentPlatform {
    if (kIsWeb) return false;
    return supportedPlatforms.contains(
      Platform.operatingSystem == 'macos'
          ? TargetPlatform.macOS
          : Platform.operatingSystem == 'windows'
          ? TargetPlatform.windows
          : Platform.operatingSystem == 'linux'
          ? TargetPlatform.linux
          : Platform.operatingSystem == 'android'
          ? TargetPlatform.android
          : TargetPlatform.iOS,
    );
  }

  /// Execute the export with the given config.
  /// Returns a user-facing success message.
  Future<String> export(ExportConfig config);
}

/// All available export tools.
List<ExportTool> get allExportTools => [
  const CCSwitchExportTool(),
  const CherryStudioExportTool(),
  const ClaudeCodeRouterExportTool(),
  const CliProxyExportTool(),
  const KiloCodeExportTool(),
  const KelivoExportTool(),
];

/// Export tools filtered by current platform.
List<ExportTool> get platformExportTools =>
    allExportTools.where((t) => t.supportsCurrentPlatform).toList();

/// CC-Switch deeplink export tool.
class CCSwitchExportTool extends ExportTool {
  const CCSwitchExportTool();

  @override
  String get name => 'CC-Switch';

  @override
  IconData get icon => Icons.swap_horiz;

  @override
  bool get isDeeplink => true;

  @override
  List<TargetPlatform> get supportedPlatforms => const [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];

  /// Maps channel type to CC-Switch `app` parameter.
  static String _appParam(ChannelType type) => switch (type) {
    ChannelType.openai => 'codex',
    ChannelType.anthropic => 'claude',
    ChannelType.gemini => 'gemini',
  };

  @override
  Future<String> export(ExportConfig config) async {
    final queryParams = <String, String>{
      'resource': 'provider',
      'app': _appParam(config.channelType),
      'name': config.name,
      'endpoint': config.endpointUrl,
      'apiKey': config.apiKey,
    };
    if (config.homepage.isNotEmpty) {
      queryParams['homepage'] = config.homepage;
    }
    final params = Uri(queryParameters: queryParams);
    final uri = Uri.parse('ccswitch://v1/import?${params.query}');
    await launchUrl(uri);
    return uri.toString();
  }
}

/// Kelivo share-string export tool.
class KelivoExportTool extends ExportTool {
  const KelivoExportTool();

  @override
  String get name => 'Kelivo';

  @override
  IconData get icon => Icons.share;

  @override
  List<TargetPlatform> get supportedPlatforms => const [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ];

  /// Maps channel type to Kelivo `type` field.
  static String _typeField(ChannelType type) => switch (type) {
    ChannelType.openai => 'openai',
    ChannelType.anthropic => 'claude',
    ChannelType.gemini => 'google',
  };

  @override
  Future<String> export(ExportConfig config) async {
    final json = jsonEncode({
      'type': _typeField(config.channelType),
      'name': config.name,
      'apiKey': config.apiKey,
      'baseUrl': config.endpointUrl,
    });
    final encoded = base64Encode(utf8.encode(json));
    return 'ai-provider:v1:$encoded';
  }
}

/// Cherry Studio deeplink export tool.
///
/// Opens `cherrystudio://providers/api-keys?v=1&data={base64}` where the
/// payload is `{id, baseUrl, apiKey, name}`. Mirrors all-api-hub's
/// `OpenInCherryStudio` integration.
class CherryStudioExportTool extends ExportTool {
  const CherryStudioExportTool();

  @override
  String get name => 'Cherry Studio';

  @override
  IconData get icon => Icons.rocket_launch_outlined;

  @override
  bool get isDeeplink => true;

  @override
  List<TargetPlatform> get supportedPlatforms => const [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];

  @override
  Future<String> export(ExportConfig config) async {
    final json = jsonEncode({
      'id': config.name,
      'baseUrl': config.endpointUrl,
      'apiKey': config.apiKey,
      'name': config.name,
    });
    final encoded = base64Encode(utf8.encode(json));
    final uri = Uri.parse(
      'cherrystudio://providers/api-keys?v=1&data=$encoded',
    );
    await launchUrl(uri);
    return uri.toString();
  }
}

/// Claude Code Router config export tool.
///
/// CCR is configured by writing a provider entry into the router's
/// `Providers` list. all-api-hub writes it through the router's local HTTP
/// API; here we export the provider JSON so the user can paste it into
/// `~/.claude-code-router/config.json`.
class ClaudeCodeRouterExportTool extends ExportTool {
  const ClaudeCodeRouterExportTool();

  @override
  String get name => 'Claude Code Router';

  @override
  IconData get icon => Icons.route_outlined;

  @override
  List<TargetPlatform> get supportedPlatforms => const [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];

  @override
  Future<String> export(ExportConfig config) async {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'name': config.name,
      'api_base_url': config.endpointUrl,
      'api_key': config.apiKey,
      'models': <String>[],
    });
  }
}

/// CLIProxyAPI provider config export tool.
///
/// Exports an OpenAI-compatible provider entry for CLIProxyAPI's
/// `config.json` (the `{base-url, api-key}` shape used by its management
/// API), for the user to paste into their CLIProxyAPI config.
class CliProxyExportTool extends ExportTool {
  const CliProxyExportTool();

  @override
  String get name => 'CLIProxyAPI';

  @override
  IconData get icon => Icons.hub_outlined;

  @override
  List<TargetPlatform> get supportedPlatforms => const [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];

  @override
  Future<String> export(ExportConfig config) async {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'name': config.name,
      'base-url': config.endpointUrl,
      'api-key': config.apiKey,
    });
  }
}

/// Kilo Code settings export tool.
///
/// Exports an OpenAI-compatible provider profile in Kilo Code's
/// `kilo-settings.json` shape for the user to merge into their settings.
class KiloCodeExportTool extends ExportTool {
  const KiloCodeExportTool();

  @override
  String get name => 'Kilo Code';

  @override
  IconData get icon => Icons.code_outlined;

  @override
  List<TargetPlatform> get supportedPlatforms => const [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];

  @override
  Future<String> export(ExportConfig config) async {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'provider': 'openai',
      'openAiBaseUrl': config.endpointUrl,
      'openAiApiKey': config.apiKey,
      'openAiModelId': '',
    });
  }
}
