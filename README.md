# roadway_native_navigation

Renders a native Android `BottomNavigationView` or iOS `UITabBar`. It does not
own navigation state: use the selected callback to delegate transitions to
`go_router`. Built-in icons are native vectors on Android and SF Symbols on
iOS.

```dart
NativeNavigationBar(
  items: const <NativeNavigationItem>[
    NativeNavigationItem(label: 'Home', icon: NativeNavigationIcon.home),
  ],
  selectedIndex: navigationShell.currentIndex,
  onItemSelected: navigationShell.goBranch,
)
```

Provide between one and five items. The selected index is synchronized from
Flutter to the native control, while taps are sent back through
`onItemSelected`.

## Custom bar and native design requirements

Pass `customBuilder` to render your own Flutter bar instead of the native
control. It receives the items, the selected index and the selection callback.
It is also used on platforms without a native implementation (web, desktop).

```dart
NativeNavigationBar(
  items: items,
  selectedIndex: navigationShell.currentIndex,
  onItemSelected: navigationShell.goBranch,
  requireLiquidGlass: true,
  requireMaterial3Expressive: true,
  customBuilder: (context, items, selectedIndex, onItemSelected) =>
      MyNavigationBar(
        items: items,
        selectedIndex: selectedIndex,
        onItemSelected: onItemSelected,
      ),
)
```

| Flag | Default | iOS | Android |
| --- | --- | --- | --- |
| `useNativeOnIOS` | `true` | `false` always renders `customBuilder`. | — |
| `requireLiquidGlass` | `false` | Native `UITabBar` only with Liquid Glass, otherwise `customBuilder`. | — |
| `useNativeOnAndroid` | `true` | — | `false` always renders `customBuilder`. |
| `requireMaterial3Expressive` | `false` | — | Native `BottomNavigationView` styled with Material 3 Expressive only when supported, otherwise `customBuilder`. |

Liquid Glass is available on iOS 26 and later, when the app is built with the
iOS 26 SDK (Xcode 26+) and `UIDesignRequiresCompatibility` is not enabled in
`Info.plist`. Material 3 Expressive is used on Android 16 (API 36) and later.
Without `requireMaterial3Expressive`, Android renders the classic Material 3
bar. Query the same checks with `NativeNavigationCapabilities.current()`.

Debug builds assert invalid combinations:

* `customBuilder` is required when `useNativeOnIOS` or `useNativeOnAndroid`
  is `false`, and as the fallback for `requireLiquidGlass` or
  `requireMaterial3Expressive`.
* `requireLiquidGlass` requires `useNativeOnIOS`, and
  `requireMaterial3Expressive` requires `useNativeOnAndroid`.

## Dynamic items

Items can change at runtime (for example, when a feature flag enables a new
section). Rebuild the widget with the new list and the native control updates
in place, without recreating the platform view. Items are compared by value, so
both a new list and items added to the same list instance are detected.

```dart
setState(() => items.add(
  const NativeNavigationItem(label: 'Search', icon: NativeNavigationIcon.search),
));
```

Keep `selectedIndex` within the new list's range when removing items.

## Custom icons

Pass `iconAsset` for a PNG declared in the host application's `pubspec.yaml`,
or pass image bytes through `iconBytes`. Assets are loaded in Flutter and sent
to the native view, where they are tinted for selected and unselected states.

```dart
NativeNavigationItem(
  label: 'Profile',
  iconAsset: 'assets/icons/profile.png',
)
```
