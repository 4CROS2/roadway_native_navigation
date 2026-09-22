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
