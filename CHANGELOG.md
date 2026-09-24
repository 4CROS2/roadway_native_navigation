## Unreleased

* Update native navigation items in place when `NativeNavigationBar.items` changes.
* Compare `NativeNavigationItem` instances by value.
* Add `customBuilder` to render a Flutter bar instead of the native control.
* Add `useNativeOnIOS` and `requireLiquidGlass` (iOS 26+) flags.
* Add `useNativeOnAndroid` and `requireMaterial3Expressive` (Android 16+) flags.
* Add `NativeNavigationCapabilities` to query Liquid Glass and Material 3 Expressive support.
* Assert invalid flag combinations.
* Upgrade Material Components for Android to 1.14.0.
* Fix a native view created with stale items when items changed during its creation.

## 0.1.0

* Add native Android and iOS navigation bars driven by Flutter navigation state.
* Support PNG assets and image bytes for custom navigation icons.
* Replace Android system bitmap icons with scalable Material vectors.

## 0.0.1

* TODO: Describe initial release.
