import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_navigation_capabilities.dart';

const String _viewType = 'roadway_native_navigation/navigation_bar';
const String _channelPrefix = 'roadway_native_navigation/navigation_bar/';
const int _customIconSize = 25;

enum NativeNavigationIcon { home, search, favorites, profile }

/// Builds a Flutter navigation bar used instead of the native control.
typedef NativeNavigationBarBuilder = Widget Function(
  BuildContext context,
  List<NativeNavigationItem> items,
  int selectedIndex,
  ValueChanged<int> onItemSelected,
);

class NativeNavigationItem {
  const NativeNavigationItem({
    required this.label,
    this.icon,
    this.iconAsset,
    this.iconBytes,
  }) : assert(
         icon != null || iconAsset != null || iconBytes != null,
         'Provide a native icon, Flutter asset, or image bytes.',
       ),
       assert(
         iconAsset == null || iconBytes == null,
         'Provide either an asset or image bytes, not both.',
       );

  final String label;
  final NativeNavigationIcon? icon;
  final String? iconAsset;
  final Uint8List? iconBytes;

  @override
  bool operator ==(Object other) {
    return other is NativeNavigationItem &&
        other.label == label &&
        other.icon == icon &&
        other.iconAsset == iconAsset &&
        listEquals(other.iconBytes, iconBytes);
  }

  @override
  int get hashCode => Object.hash(
    label,
    icon,
    iconAsset,
    iconBytes == null ? null : Object.hashAll(iconBytes!),
  );

  Future<Map<String, Object>> toCreationParams() async {
    final Map<String, Object> params = <String, Object>{'label': label};
    final Uint8List? imageBytes = iconBytes ?? await _loadIconAsset();

    if (imageBytes != null) {
      params['iconBytes'] = imageBytes;
    } else {
      params['icon'] = icon!.name;
    }

    return params;
  }

  Future<Uint8List?> _loadIconAsset() async {
    final String? asset = iconAsset;
    if (asset == null) return null;

    final ByteData data = await rootBundle.load(asset);
    final Uint8List bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return _resizeIcon(bytes);
  }
}

class NativeNavigationBar extends StatefulWidget {
  NativeNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.customBuilder,
    this.useNativeOnIOS = true,
    this.requireLiquidGlass = false,
    this.useNativeOnAndroid = true,
    this.requireMaterial3Expressive = false,
  }) : assert(items.isNotEmpty, 'Native navigation requires at least one item'),
       assert(
         items.length <= 5,
         'Native navigation supports at most five items',
       ),
       assert(
         selectedIndex >= 0 && selectedIndex < items.length,
         'selectedIndex must identify an item',
       ),
       assert(
         useNativeOnIOS || customBuilder != null,
         'customBuilder is required when useNativeOnIOS is false',
       ),
       assert(
         !requireLiquidGlass || customBuilder != null,
         'customBuilder is required as the fallback when requireLiquidGlass '
         'is true',
       ),
       assert(
         !requireLiquidGlass || useNativeOnIOS,
         'requireLiquidGlass has no effect when useNativeOnIOS is false',
       ),
       assert(
         useNativeOnAndroid || customBuilder != null,
         'customBuilder is required when useNativeOnAndroid is false',
       ),
       assert(
         !requireMaterial3Expressive || customBuilder != null,
         'customBuilder is required as the fallback when '
         'requireMaterial3Expressive is true',
       ),
       assert(
         !requireMaterial3Expressive || useNativeOnAndroid,
         'requireMaterial3Expressive has no effect when useNativeOnAndroid is '
         'false',
       );

  final List<NativeNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  /// Flutter bar rendered instead of the native control when native rendering
  /// is disabled or its required design is unavailable. Also used on
  /// platforms without a native implementation.
  final NativeNavigationBarBuilder? customBuilder;

  /// Renders a native `UITabBar` on iOS. When false, [customBuilder] is used.
  final bool useNativeOnIOS;

  /// Renders the native `UITabBar` only when it uses Liquid Glass (iOS 26+),
  /// falling back to [customBuilder] otherwise.
  final bool requireLiquidGlass;

  /// Renders a native `BottomNavigationView` on Android. When false,
  /// [customBuilder] is used.
  final bool useNativeOnAndroid;

  /// Renders the native `BottomNavigationView` with Material 3 Expressive only
  /// when supported (Android 16+), falling back to [customBuilder] otherwise.
  final bool requireMaterial3Expressive;

  @override
  State<NativeNavigationBar> createState() => _NativeNavigationBarState();
}

class _NativeNavigationBarState extends State<NativeNavigationBar> {
  MethodChannel? _channel;

  /// Loaded lazily, only when the native view is about to be created.
  Future<Map<String, Object>>? _creationParams;

  /// Snapshot of the items last sent to the native view. Kept as a copy so
  /// in-place mutations of [NativeNavigationBar.items] are also detected.
  late List<NativeNavigationItem> _items;

  /// Discards stale item updates when several arrive before icons finish
  /// loading.
  int _itemsGeneration = 0;
  bool _itemsUpdatePending = false;

  @override
  void initState() {
    super.initState();
    _items = List<NativeNavigationItem>.of(widget.items);
  }

  @override
  void didUpdateWidget(covariant NativeNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useNativeOnIOS != widget.useNativeOnIOS ||
        oldWidget.requireLiquidGlass != widget.requireLiquidGlass ||
        oldWidget.useNativeOnAndroid != widget.useNativeOnAndroid ||
        oldWidget.requireMaterial3Expressive !=
            widget.requireMaterial3Expressive) {
      // The presentation may change: a new platform view reads fresh params.
      _channel?.setMethodCallHandler(null);
      _channel = null;
      _items = List<NativeNavigationItem>.of(widget.items);
      _itemsGeneration++;
      _itemsUpdatePending = false;
      _creationParams = null;
      return;
    }
    if (!listEquals(_items, widget.items)) {
      _items = List<NativeNavigationItem>.of(widget.items);
      _updateItems();
    } else if (oldWidget.selectedIndex != widget.selectedIndex &&
        !_itemsUpdatePending) {
      // A pending item update already carries the latest selected index.
      _channel?.invokeMethod<void>('setSelectedIndex', widget.selectedIndex);
    }
  }

  void _updateItems() {
    final int generation = ++_itemsGeneration;
    final MethodChannel? channel = _channel;
    if (channel == null) {
      // The platform view does not exist yet: create it with the new items.
      _creationParams = null;
      return;
    }

    _itemsUpdatePending = true;
    _loadCreationParams().then((Map<String, Object> value) {
      if (!mounted || generation != _itemsGeneration) return;
      _itemsUpdatePending = false;
      channel.invokeMethod<void>('setItems', value);
    });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int viewId) {
    final MethodChannel channel = MethodChannel('$_channelPrefix$viewId');
    channel.setMethodCallHandler(_handleMethodCall);
    _channel = channel;
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onItemSelected') {
      throw MissingPluginException('Unsupported method: ${call.method}');
    }

    final Object? arguments = call.arguments;
    if (arguments is! int ||
        arguments < 0 ||
        arguments >= widget.items.length) {
      throw PlatformException(
        code: 'invalid-selection',
        message: 'The native navigation item index is invalid.',
      );
    }

    widget.onItemSelected(arguments);
  }

  @override
  Widget build(BuildContext context) {
    final TargetPlatform platform = defaultTargetPlatform;
    final bool isIOS = platform == TargetPlatform.iOS;
    if (!isIOS && platform != TargetPlatform.android) {
      return widget.customBuilder == null
          ? const SizedBox.shrink()
          : _buildCustom(context);
    }

    final bool useNative = isIOS
        ? widget.useNativeOnIOS
        : widget.useNativeOnAndroid;
    if (!useNative) return _buildCustom(context);

    final bool requiresDesign = isIOS
        ? widget.requireLiquidGlass
        : widget.requireMaterial3Expressive;
    if (!requiresDesign) return _buildNative(platform, expressive: false);

    return FutureBuilder<NativeNavigationCapabilities>(
      future: NativeNavigationCapabilities.current(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<NativeNavigationCapabilities> snapshot,
          ) {
            final NativeNavigationCapabilities? capabilities = snapshot.data;
            if (capabilities == null) {
              return SizedBox(height: _nativeHeight(platform, !isIOS));
            }

            final bool supported = isIOS
                ? capabilities.supportsLiquidGlass
                : capabilities.supportsMaterial3Expressive;
            return supported
                ? _buildNative(platform, expressive: !isIOS)
                : _buildCustom(context);
          },
    );
  }

  Widget _buildCustom(BuildContext context) {
    return widget.customBuilder!(
      context,
      widget.items,
      widget.selectedIndex,
      widget.onItemSelected,
    );
  }

  Widget _buildNative(TargetPlatform platform, {required bool expressive}) {
    final double height = _nativeHeight(platform, expressive);
    final Future<Map<String, Object>> creationParams = _creationParams ??=
        _loadCreationParams();
    return FutureBuilder<Map<String, Object>>(
      // A new future must not reuse the previous snapshot's stale items.
      key: ObjectKey(creationParams),
      future: creationParams,
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, Object>> snapshot) {
            if (snapshot.hasError) return ErrorWidget(snapshot.error!);
            if (!snapshot.hasData) return SizedBox(height: height);

            final Map<String, Object> params = <String, Object>{
              ...snapshot.data!,
              'material3Expressive': expressive,
            };
            return SizedBox(
              height: height,
              child: platform == TargetPlatform.android
                  ? AndroidView(
                      viewType: _viewType,
                      onPlatformViewCreated: _onPlatformViewCreated,
                      creationParams: params,
                      creationParamsCodec: const StandardMessageCodec(),
                    )
                  : UiKitView(
                      viewType: _viewType,
                      onPlatformViewCreated: _onPlatformViewCreated,
                      creationParams: params,
                      creationParamsCodec: const StandardMessageCodec(),
                    ),
            );
          },
    );
  }

  static double _nativeHeight(TargetPlatform platform, bool expressive) {
    if (platform == TargetPlatform.iOS) return 49;
    return expressive ? 64 : 80;
  }

  Future<Map<String, Object>> _loadCreationParams() async {
    return <String, Object>{
      'items': await Future.wait(
        widget.items.map(
          (NativeNavigationItem item) => item.toCreationParams(),
        ),
      ),
      'selectedIndex': widget.selectedIndex,
    };
  }
}

Future<Uint8List> _resizeIcon(Uint8List bytes) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    bytes,
  );
  final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(
    buffer,
  );

  try {
    final double scale =
        _customIconSize / math.max(descriptor.width, descriptor.height);
    final ui.Codec codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );

    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      try {
        final ByteData? resized = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (resized == null) {
          throw StateError('Unable to encode the custom navigation icon.');
        }
        return resized.buffer.asUint8List(
          resized.offsetInBytes,
          resized.lengthInBytes,
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}
