import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'platform_env.dart';

class StartupRouteConfig {
  final String? role; // 'dewan', 'juri', 'timekeeper', 'monitoring'
  final String? arenaCode;
  final int? juriNumber;

  const StartupRouteConfig({this.role, this.arenaCode, this.juriNumber});

  bool get hasRole => role != null && role!.isNotEmpty;
}

class AppLinkHelper {
  AppLinkHelper._();

  static const String fallbackWebBaseUrl =
      'https://beseni-temp.pusakarinjani.my.id';

  /// True on Chrome/Web and Windows Desktop where opening links in a new
  /// browser tab is expected.
  static bool get supportsNewTab => kIsWeb || isWindowsDesktop();

  /// Builds a deep-link URI for a role panel (`dewan`, `juri`, `timekeeper`,
  /// `monitoring`), optionally carrying the verified [arenaCode] and [juriNumber].
  ///
  /// Uses a hash fragment (`#/?role=...`) so Flutter Web handles right-click
  /// "Open link in new tab" without needing server-side URL rewrite rules.
  static Uri buildRoleUri({
    required String role,
    String? arenaCode,
    int? juriNumber,
    Uri? baseUriOverride,
  }) {
    final params = <String, String>{'role': role.toLowerCase().trim()};
    if (arenaCode != null && arenaCode.trim().isNotEmpty) {
      params['arena'] = arenaCode.trim();
    }
    if (juriNumber != null && juriNumber >= 1 && juriNumber <= 10) {
      params['juri'] = juriNumber.toString();
    }
    final queryStr = Uri(queryParameters: params).query;
    final fragment = '/?$queryStr';

    if (baseUriOverride != null) {
      return Uri(
        scheme: baseUriOverride.scheme,
        userInfo: baseUriOverride.userInfo,
        host: baseUriOverride.host,
        port: baseUriOverride.hasPort ? baseUriOverride.port : null,
        path: baseUriOverride.path.isEmpty ? '/' : baseUriOverride.path,
        fragment: fragment,
      );
    }

    if (kIsWeb) {
      final base = Uri.base;
      return Uri(
        scheme: base.scheme,
        userInfo: base.userInfo,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: base.path.isEmpty ? '/' : base.path,
        fragment: fragment,
      );
    }

    final fallback = Uri.parse(fallbackWebBaseUrl);
    return fallback.replace(fragment: fragment);
  }

  /// Parses role, arena code, and juri number from either standard query
  /// parameters (`?role=dewan&arena=23456789`) or hash fragment routes
  /// (`#/?role=dewan&arena=23456789` / `#/dewan?arena=23456789`).
  static StartupRouteConfig parseStartupRoute(Uri uri) {
    final mergedParams = <String, String>{...uri.queryParameters};
    String? pathRole;

    if (uri.fragment.isNotEmpty) {
      final rawFrag = uri.fragment.startsWith('/')
          ? uri.fragment
          : '/${uri.fragment}';
      final fragUri = Uri.tryParse(rawFrag);
      if (fragUri != null) {
        mergedParams.addAll(fragUri.queryParameters);
        final seg = fragUri.pathSegments.isNotEmpty
            ? fragUri.pathSegments.first.toLowerCase().trim()
            : '';
        if (_isValidRole(seg)) {
          pathRole = seg;
        }
      }
    }

    if (pathRole == null && uri.pathSegments.isNotEmpty) {
      final seg = uri.pathSegments.first.toLowerCase().trim();
      if (_isValidRole(seg)) {
        pathRole = seg;
      }
    }

    final rawRole = (mergedParams['role'] ?? pathRole ?? '')
        .toLowerCase()
        .trim();
    final role = _isValidRole(rawRole) ? rawRole : null;
    final arena = mergedParams['arena']?.trim();
    final juri = int.tryParse(mergedParams['juri'] ?? '');

    return StartupRouteConfig(
      role: role,
      arenaCode: (arena != null && arena.isNotEmpty) ? arena : null,
      juriNumber: (juri != null && juri >= 1 && juri <= 10) ? juri : null,
    );
  }

  static bool _isValidRole(String value) {
    return value == 'dewan' ||
        value == 'juri' ||
        value == 'timekeeper' ||
        value == 'monitoring';
  }

  /// Opens the given role panel link in a new browser tab (`_blank` on Web,
  /// external default browser tab on Windows Desktop).
  static Future<bool> openRoleInNewTab({
    required String role,
    String? arenaCode,
    int? juriNumber,
  }) async {
    final uri = buildRoleUri(
      role: role,
      arenaCode: arenaCode,
      juriNumber: juriNumber,
    );
    try {
      return await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      return false;
    }
  }
}
