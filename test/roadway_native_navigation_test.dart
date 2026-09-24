import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadway_native_navigation/roadway_native_navigation.dart';

const NativeNavigationItem home = NativeNavigationItem(
  label: 'Home',
  icon: NativeNavigationIcon.home,
);
const NativeNavigationItem search = NativeNavigationItem(
  label: 'Search',
  icon: NativeNavigationIcon.search,
);
const Key customBarKey = Key('custom-bar');
const MethodChannel pluginChannel = MethodChannel('roadway_native_navigation');

TestDefaultBinaryMessenger get messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

Widget customBar(
  BuildContext context,
  List<NativeNavigationItem> items,
  int selectedIndex,
  ValueChanged<int> onItemSelected,
) {
  return Row(
    key: customBarKey,
    children: <Widget>[
      for (int i = 0; i < items.length; i++)
        TextButton(
          onPressed: () => onItemSelected(i),
          child: Text(
            i == selectedIndex ? '[${items[i].label}]' : items[i].label,
          ),
        ),
    ],
  );
}

/// Fakes the platform views system channel and records calls sent to every
/// created native navigation view.
class FakeNativeViews {
  final List<Map<Object?, Object?>> created = <Map<Object?, Object?>>[];
  final List<MethodCall> calls = <MethodCall>[];
  final List<MethodChannel> _channels = <MethodChannel>[];

  Map<Object?, Object?> get lastParams {
    final Map<Object?, Object?> args = created.last;
    final Object? params = args['params'];
    return const StandardMessageCodec().decodeMessage(
      ByteData.sublistView(params! as Uint8List),
    ) as Map<Object?, Object?>;
  }

  MethodChannel get lastChannel => _channels.last;

  void install() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      MethodCall call,
    ) async {
      final Map<Object?, Object?>? args = call.arguments is Map
          ? call.arguments as Map<Object?, Object?>
          : null;
      switch (call.method) {
        case 'create':
          created.add(args!);
          final MethodChannel channel = MethodChannel(
            'roadway_native_navigation/navigation_bar/${args['id']}',
          );
          _channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return null;
          });
          return args['width'] == null ? null : 0;
        case 'resize':
          return <String, Object?>{
            'width': args!['width'],
            'height': args['height'],
          };
      }
      return null;
    });
  }

  void uninstall() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final MethodChannel channel in _channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  }

  /// Simulates the native view invoking [method] on Flutter.
  Future<Object?> sendFromNative(String method, Object? arguments) async {
    const StandardMethodCodec codec = StandardMethodCodec();
    ByteData? reply;
    await messenger.handlePlatformMessage(
      lastChannel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (ByteData? data) => reply = data,
    );
    if (reply == null) throw MissingPluginException(method);
    return codec.decodeEnvelope(reply!);
  }
}

void mockCapabilities(Map<String, bool>? values) {
  messenger.setMockMethodCallHandler(
    pluginChannel,
    (MethodCall call) async => values,
  );
}

Widget app(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.bottomCenter, child: child),
  );
}

Future<Uint8List> pngBytes(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF000000),
  );
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  try {
    final ByteData data = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

void main() {
  late FakeNativeViews views;

  setUp(() {
    NativeNavigationCapabilities.debugReset();
    views = FakeNativeViews()..install();
  });

  tearDown(() {
    views.uninstall();
    messenger.setMockMethodCallHandler(pluginChannel, null);
  });

  group('asserts', () {
    NativeNavigationBar build({
      List<NativeNavigationItem> items = const <NativeNavigationItem>[home],
      int selectedIndex = 0,
      NativeNavigationBarBuilder? customBuilder,
      bool useNativeOnIOS = true,
      bool requireLiquidGlass = false,
      bool useNativeOnAndroid = true,
      bool requireMaterial3Expressive = false,
    }) {
      return NativeNavigationBar(
        items: items,
        selectedIndex: selectedIndex,
        onItemSelected: (_) {},
        customBuilder: customBuilder,
        useNativeOnIOS: useNativeOnIOS,
        requireLiquidGlass: requireLiquidGlass,
        useNativeOnAndroid: useNativeOnAndroid,
        requireMaterial3Expressive: requireMaterial3Expressive,
      );
    }

    test('reject empty items, more than five items and bad selection', () {
      expect(
        () => build(items: const <NativeNavigationItem>[]),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => build(items: List<NativeNavigationItem>.filled(6, home)),
        throwsAssertionError,
      );
      expect(() => build(selectedIndex: 1), throwsAssertionError);
    });

    test('require a customBuilder when native rendering is disabled', () {
      expect(() => build(useNativeOnIOS: false), throwsAssertionError);
      expect(() => build(useNativeOnAndroid: false), throwsAssertionError);
    });

    test('require a customBuilder as the design fallback', () {
      expect(() => build(requireLiquidGlass: true), throwsAssertionError);
      expect(
        () => build(requireMaterial3Expressive: true),
        throwsAssertionError,
      );
    });

    test('reject design requirements when native rendering is disabled', () {
      expect(
        () => build(
          customBuilder: customBar,
          useNativeOnIOS: false,
          requireLiquidGlass: true,
        ),
        throwsAssertionError,
      );
      expect(
        () => build(
          customBuilder: customBar,
          useNativeOnAndroid: false,
          requireMaterial3Expressive: true,
        ),
        throwsAssertionError,
      );
    });

    test('accept every valid flag combination', () {
      expect(build(), isNotNull);
      expect(build(customBuilder: customBar), isNotNull);
      expect(
        build(
          customBuilder: customBar,
          useNativeOnIOS: false,
          useNativeOnAndroid: false,
        ),
        isNotNull,
      );
      expect(
        build(
          customBuilder: customBar,
          requireLiquidGlass: true,
          requireMaterial3Expressive: true,
        ),
        isNotNull,
      );
    });
  });

  group('NativeNavigationItem', () {
    test('asserts that an icon source is provided exactly once', () {
      expect(() => NativeNavigationItem(label: 'Home'), throwsAssertionError);
      expect(
        () => NativeNavigationItem(
          label: 'Home',
          iconAsset: 'a.png',
          iconBytes: Uint8List(1),
        ),
        throwsAssertionError,
      );
    });

    test('compares items by value', () {
      final NativeNavigationItem a = NativeNavigationItem(
        label: 'Home',
        iconBytes: Uint8List.fromList(<int>[1, 2, 3]),
      );
      final NativeNavigationItem b = NativeNavigationItem(
        label: 'Home',
        iconBytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(home));
      expect(home.hashCode, home.hashCode);
    });

    test('serializes a built-in icon by name', () async {
      expect(await home.toCreationParams(), <String, Object>{
        'label': 'Home',
        'icon': 'home',
      });
    });

    test('serializes supplied image bytes', () async {
      final NativeNavigationItem item = NativeNavigationItem(
        label: 'Home',
        iconBytes: Uint8List.fromList(<int>[137, 80, 78, 71]),
      );

      final Map<String, Object> params = await item.toCreationParams();

      expect(params['label'], 'Home');
      expect(params['iconBytes'], isA<Uint8List>());
      expect(params.containsKey('icon'), isFalse);
    });

    test('resizes asset icons to fit 25 logical pixels', () async {
      final Uint8List png = await pngBytes(100, 50);
      messenger.setMockMessageHandler('flutter/assets', (ByteData? key) async {
        return ByteData.sublistView(png);
      });
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );
      const NativeNavigationItem item = NativeNavigationItem(
        label: 'Custom',
        iconAsset: 'assets/icons/custom.png',
      );

      final Map<String, Object> params = await item.toCreationParams();
      final ui.Codec codec = await ui.instantiateImageCodec(
        params['iconBytes']! as Uint8List,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();

      expect(frame.image.width, 25);
      expect(frame.image.height, 13);
      frame.image.dispose();
      codec.dispose();
    });
  });

  group('NativeNavigationCapabilities', () {
    test('reads capabilities from the platform and caches them', () async {
      int calls = 0;
      messenger.setMockMethodCallHandler(pluginChannel, (
        MethodCall call,
      ) async {
        calls++;
        expect(call.method, 'getCapabilities');
        return <String, bool>{'liquidGlass': true, 'material3Expressive': true};
      });

      final NativeNavigationCapabilities first =
          await NativeNavigationCapabilities.current();
      await NativeNavigationCapabilities.current();

      expect(first.supportsLiquidGlass, isTrue);
      expect(first.supportsMaterial3Expressive, isTrue);
      expect(calls, 1);
    });

    test('reports nothing when the platform returns no values', () async {
      mockCapabilities(null);

      final NativeNavigationCapabilities capabilities =
          await NativeNavigationCapabilities.current();

      expect(capabilities.supportsLiquidGlass, isFalse);
      expect(capabilities.supportsMaterial3Expressive, isFalse);
    });

    test('reports nothing when the platform fails', () async {
      messenger.setMockMethodCallHandler(pluginChannel, (MethodCall call) {
        throw PlatformException(code: 'boom');
      });

      final NativeNavigationCapabilities capabilities =
          await NativeNavigationCapabilities.current();

      expect(capabilities.supportsLiquidGlass, isFalse);
    });

    test('reports nothing when the plugin is missing', () async {
      final NativeNavigationCapabilities capabilities =
          await NativeNavigationCapabilities.current();

      expect(capabilities.supportsMaterial3Expressive, isFalse);
    });
  });

  group('presentation', () {
    Widget bar({
      int selectedIndex = 0,
      ValueChanged<int>? onItemSelected,
      NativeNavigationBarBuilder? customBuilder,
      bool useNativeOnIOS = true,
      bool requireLiquidGlass = false,
      bool useNativeOnAndroid = true,
      bool requireMaterial3Expressive = false,
    }) {
      return app(
        NativeNavigationBar(
          items: const <NativeNavigationItem>[home, search],
          selectedIndex: selectedIndex,
          onItemSelected: onItemSelected ?? (_) {},
          customBuilder: customBuilder,
          useNativeOnIOS: useNativeOnIOS,
          requireLiquidGlass: requireLiquidGlass,
          useNativeOnAndroid: useNativeOnAndroid,
          requireMaterial3Expressive: requireMaterial3Expressive,
        ),
      );
    }

    double barHeight(WidgetTester tester) =>
        tester.getSize(find.byType(NativeNavigationBar)).height;

    testWidgets(
      'renders nothing on unsupported platforms without a customBuilder',
      (WidgetTester tester) async {
        await tester.pumpWidget(bar());

        expect(find.byType(AndroidView), findsNothing);
        expect(find.byType(UiKitView), findsNothing);
        expect(barHeight(tester), 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('renders the customBuilder on unsupported platforms', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(bar(customBuilder: customBar));

      expect(find.byKey(customBarKey), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('renders a native UITabBar on iOS by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(bar(customBuilder: customBar));
      await tester.pumpAndSettle();

      expect(find.byType(UiKitView), findsOneWidget);
      expect(find.byKey(customBarKey), findsNothing);
      expect(barHeight(tester), 49);
      expect(views.lastParams['selectedIndex'], 0);
      expect(views.lastParams['items'], hasLength(2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('renders the customBuilder when useNativeOnIOS is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        bar(customBuilder: customBar, useNativeOnIOS: false),
      );

      expect(find.byKey(customBarKey), findsOneWidget);
      expect(find.byType(UiKitView), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('renders the native UITabBar when Liquid Glass is available', (
      WidgetTester tester,
    ) async {
      mockCapabilities(<String, bool>{'liquidGlass': true});

      await tester.pumpWidget(
        bar(customBuilder: customBar, requireLiquidGlass: true),
      );
      expect(barHeight(tester), 49, reason: 'placeholder while resolving');
      await tester.pumpAndSettle();

      expect(find.byType(UiKitView), findsOneWidget);
      expect(find.byKey(customBarKey), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('falls back to the customBuilder without Liquid Glass', (
      WidgetTester tester,
    ) async {
      mockCapabilities(<String, bool>{'liquidGlass': false});

      await tester.pumpWidget(
        bar(customBuilder: customBar, requireLiquidGlass: true),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(customBarKey), findsOneWidget);
      expect(find.byType(UiKitView), findsNothing);
      expect(views.created, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('ignores requireMaterial3Expressive on iOS', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        bar(customBuilder: customBar, requireMaterial3Expressive: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UiKitView), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'renders a classic native BottomNavigationView on Android by default',
      (WidgetTester tester) async {
        await tester.pumpWidget(bar());
        await tester.pumpAndSettle();

        expect(find.byType(AndroidView), findsOneWidget);
        expect(barHeight(tester), 80);
        expect(views.lastParams['material3Expressive'], isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('renders the customBuilder when useNativeOnAndroid is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        bar(customBuilder: customBar, useNativeOnAndroid: false),
      );

      expect(find.byKey(customBarKey), findsOneWidget);
      expect(find.byType(AndroidView), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('renders a Material 3 Expressive native bar when supported', (
      WidgetTester tester,
    ) async {
      mockCapabilities(<String, bool>{'material3Expressive': true});

      await tester.pumpWidget(
        bar(customBuilder: customBar, requireMaterial3Expressive: true),
      );
      expect(barHeight(tester), 64, reason: 'placeholder while resolving');
      await tester.pumpAndSettle();

      expect(find.byType(AndroidView), findsOneWidget);
      expect(barHeight(tester), 64);
      expect(views.lastParams['material3Expressive'], isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets(
      'falls back to the customBuilder without Material 3 Expressive',
      (WidgetTester tester) async {
        mockCapabilities(<String, bool>{'material3Expressive': false});

        await tester.pumpWidget(
          bar(customBuilder: customBar, requireMaterial3Expressive: true),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(customBarKey), findsOneWidget);
        expect(find.byType(AndroidView), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('passes items, selection and callback to the customBuilder', (
      WidgetTester tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        bar(
          selectedIndex: 1,
          onItemSelected: (int index) => selected = index,
          customBuilder: customBar,
          useNativeOnAndroid: false,
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('[Search]'), findsOneWidget);
      await tester.tap(find.text('Home'));
      expect(selected, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets(
      'recreates the native view when flags switch back from custom',
      (WidgetTester tester) async {
        await tester.pumpWidget(bar(customBuilder: customBar));
        await tester.pumpAndSettle();
        expect(views.created, hasLength(1));

        await tester.pumpWidget(
          bar(customBuilder: customBar, useNativeOnAndroid: false),
        );
        expect(find.byKey(customBarKey), findsOneWidget);

        await tester.pumpWidget(
          bar(customBuilder: customBar, selectedIndex: 1),
        );
        await tester.pumpAndSettle();

        expect(views.created, hasLength(2));
        expect(views.lastParams['selectedIndex'], 1);
        expect(views.calls, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('shows an ErrorWidget when an icon asset cannot be loaded', (
      WidgetTester tester,
    ) async {
      messenger.setMockMessageHandler('flutter/assets', (_) async => null);
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );
      await tester.pumpWidget(
        app(
          NativeNavigationBar(
            items: const <NativeNavigationItem>[
              NativeNavigationItem(label: 'Home', iconAsset: 'missing.png'),
            ],
            selectedIndex: 0,
            onItemSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorWidget), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('live updates', () {
    final TargetPlatformVariant ios = TargetPlatformVariant.only(
      TargetPlatform.iOS,
    );

    Widget buildBar(List<NativeNavigationItem> items, int selectedIndex) {
      return app(
        NativeNavigationBar(
          items: items,
          selectedIndex: selectedIndex,
          onItemSelected: (_) {},
        ),
      );
    }

    testWidgets('sends new items to the native view when one is added', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildBar(<NativeNavigationItem>[home], 0));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildBar(<NativeNavigationItem>[home, search], 1),
      );
      await tester.pumpAndSettle();

      expect(views.calls, hasLength(1));
      expect(views.calls.single.method, 'setItems');
      final Map<Object?, Object?> args =
          views.calls.single.arguments as Map<Object?, Object?>;
      expect(args['selectedIndex'], 1);
      expect(args['items'], hasLength(2));
    }, variant: ios);

    testWidgets('detects items added to the same list instance', (
      WidgetTester tester,
    ) async {
      final List<NativeNavigationItem> items = <NativeNavigationItem>[home];
      await tester.pumpWidget(buildBar(items, 0));
      await tester.pumpAndSettle();

      items.add(search);
      await tester.pumpWidget(buildBar(items, 0));
      await tester.pumpAndSettle();

      expect(views.calls.map((MethodCall c) => c.method), <String>['setItems']);
    }, variant: ios);

    testWidgets('only updates the selection when items are unchanged', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildBar(<NativeNavigationItem>[home, search], 0),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildBar(<NativeNavigationItem>[home, search], 1),
      );
      await tester.pumpAndSettle();

      expect(views.calls, hasLength(1));
      expect(views.calls.single.method, 'setSelectedIndex');
      expect(views.calls.single.arguments, 1);
    }, variant: ios);

    testWidgets('creates the view with items changed before it existed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildBar(<NativeNavigationItem>[home], 0));
      await tester.pumpWidget(
        buildBar(<NativeNavigationItem>[home, search], 0),
      );
      await tester.pumpAndSettle();

      expect(views.created, hasLength(1));
      expect(views.lastParams['items'], hasLength(2));
      expect(views.calls, isEmpty);
    }, variant: ios);
  });

  group('native callbacks', () {
    final TargetPlatformVariant android = TargetPlatformVariant.only(
      TargetPlatform.android,
    );

    Future<List<int>> pumpNative(WidgetTester tester) async {
      final List<int> selections = <int>[];
      await tester.pumpWidget(
        app(
          NativeNavigationBar(
            items: const <NativeNavigationItem>[home, search],
            selectedIndex: 0,
            onItemSelected: selections.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return selections;
    }

    testWidgets('forwards native selections to onItemSelected', (
      WidgetTester tester,
    ) async {
      final List<int> selections = await pumpNative(tester);

      await views.sendFromNative('onItemSelected', 1);

      expect(selections, <int>[1]);
    }, variant: android);

    testWidgets('rejects invalid native selections', (
      WidgetTester tester,
    ) async {
      final List<int> selections = await pumpNative(tester);

      expect(
        views.sendFromNative('onItemSelected', 5),
        throwsA(
          isA<PlatformException>().having(
            (PlatformException e) => e.code,
            'code',
            'invalid-selection',
          ),
        ),
      );
      expect(selections, isEmpty);
    }, variant: android);

    testWidgets('rejects unknown native methods', (WidgetTester tester) async {
      await pumpNative(tester);

      expect(
        views.sendFromNative('unknown', null),
        throwsA(isA<MissingPluginException>()),
      );
    }, variant: android);
  });
}
