import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String _viewType = 'roadway_native_navigation/navigation_bar';
const String _channelPrefix = 'roadway_native_navigation/navigation_bar/';
const int _customIconSize = 25;

enum NativeNavigationIcon { home, search, favorites, profile }

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
  }) : assert(items.isNotEmpty, 'Native navigation requires at least one item'),
       assert(
         items.length <= 5,
         'Native navigation supports at most five items',
       ),
       assert(
         selectedIndex >= 0 && selectedIndex < items.length,
         'selectedIndex must identify an item',
       );

  final List<NativeNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  @override
  State<NativeNavigationBar> createState() => _NativeNavigationBarState();
}

class _NativeNavigationBarState extends State<NativeNavigationBar> {
  MethodChannel? _channel;
  late Future<Map<String, Object>> _creationParams;

  @override
  void initState() {
    super.initState();
    _creationParams = _loadCreationParams();
  }

  @override
  void didUpdateWidget(covariant NativeNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _creationParams = _loadCreationParams();
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _channel?.invokeMethod<void>('setSelectedIndex', widget.selectedIndex);
    }
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
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    final double height = platform == TargetPlatform.android ? 80 : 49;
    return FutureBuilder<Map<String, Object>>(
      future: _creationParams,
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, Object>> snapshot) {
            if (snapshot.hasError) return ErrorWidget(snapshot.error!);
            if (!snapshot.hasData) return SizedBox(height: height);

            return SizedBox(
              height: height,
              child: platform == TargetPlatform.android
                  ? AndroidView(
                      viewType: _viewType,
                      onPlatformViewCreated: _onPlatformViewCreated,
                      creationParams: snapshot.data,
                      creationParamsCodec: const StandardMessageCodec(),
                    )
                  : UiKitView(
                      viewType: _viewType,
                      onPlatformViewCreated: _onPlatformViewCreated,
                      creationParams: snapshot.data,
                      creationParamsCodec: const StandardMessageCodec(),
                    ),
            );
          },
    );
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
