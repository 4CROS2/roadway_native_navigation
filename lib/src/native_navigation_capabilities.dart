import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('roadway_native_navigation');

/// Native design capabilities of the current device.
///
/// Queried once from the platform and cached for the lifetime of the app.
@immutable
class NativeNavigationCapabilities {
  const NativeNavigationCapabilities({
    this.supportsLiquidGlass = false,
    this.supportsMaterial3Expressive = false,
  });

  /// Whether the native iOS tab bar renders with Liquid Glass: iOS 26+, built
  /// with the iOS 26 SDK and without `UIDesignRequiresCompatibility` enabled.
  final bool supportsLiquidGlass;

  /// Whether the native Android navigation bar uses Material 3 Expressive:
  /// Android 16 (API 36) or later.
  final bool supportsMaterial3Expressive;

  static Future<NativeNavigationCapabilities>? _current;

  /// Returns the cached capabilities, querying the platform on first use.
  ///
  /// Resolves to no capabilities when the platform cannot answer.
  static Future<NativeNavigationCapabilities> current() {
    return _current ??= _load();
  }

  /// Clears the cached capabilities so the next [current] call queries again.
  @visibleForTesting
  static void debugReset() => _current = null;

  static Future<NativeNavigationCapabilities> _load() async {
    try {
      final Map<String, bool>? values = await _channel
          .invokeMapMethod<String, bool>('getCapabilities');
      return NativeNavigationCapabilities(
        supportsLiquidGlass: values?['liquidGlass'] ?? false,
        supportsMaterial3Expressive: values?['material3Expressive'] ?? false,
      );
    } on PlatformException {
      return const NativeNavigationCapabilities();
    } on MissingPluginException {
      return const NativeNavigationCapabilities();
    }
  }
}
