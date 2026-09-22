import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadway_native_navigation/roadway_native_navigation.dart';

void main() {
  testWidgets('does not render a platform view on unsupported platforms', (
    WidgetTester tester,
  ) async {
    // Arrange
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    // Act
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NativeNavigationBar(
          items: const <NativeNavigationItem>[
            NativeNavigationItem(
              label: 'Home',
              icon: NativeNavigationIcon.home,
            ),
          ],
          selectedIndex: 0,
          onItemSelected: (_) {},
        ),
      ),
    );

    // Assert
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(UiKitView), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  test('rejects an out-of-range selected index', () {
    // Arrange / Act / Assert
    expect(
      () => NativeNavigationBar(
        items: const <NativeNavigationItem>[
          NativeNavigationItem(label: 'Home', icon: NativeNavigationIcon.home),
        ],
        selectedIndex: 1,
        onItemSelected: (_) {},
      ),
      throwsAssertionError,
    );
  });

  test('serializes supplied image bytes for the native platform', () async {
    // Arrange
    final NativeNavigationItem item = NativeNavigationItem(
      label: 'Home',
      iconBytes: Uint8List.fromList(<int>[137, 80, 78, 71]),
    );

    // Act
    final Map<String, Object> params = await item.toCreationParams();

    // Assert
    expect(params['label'], 'Home');
    expect(params['iconBytes'], isA<Uint8List>());
    expect(params.containsKey('icon'), isFalse);
  });

  test(
    'resizes custom icon assets before sending them to the platform',
    () async {
      // Arrange
      const NativeNavigationItem item = NativeNavigationItem(
        label: 'Custom',
        iconAsset: 'assets/icons/ic_roadway.png',
      );

      // Act
      final Map<String, Object> params = await item.toCreationParams();
      final ui.Codec codec = await ui.instantiateImageCodec(
        params['iconBytes']! as Uint8List,
      );

      // Assert
      try {
        final ui.FrameInfo frame = await codec.getNextFrame();
        try {
          expect(frame.image.width, lessThanOrEqualTo(25));
          expect(frame.image.height, lessThanOrEqualTo(25));
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    },
  );
}
