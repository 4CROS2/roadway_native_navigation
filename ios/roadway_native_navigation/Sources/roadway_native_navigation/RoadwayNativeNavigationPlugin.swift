import Flutter
import UIKit

public class RoadwayNativeNavigationPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeNavigationBarFactory(messenger: registrar.messenger()),
      withId: "roadway_native_navigation/navigation_bar"
    )
    let channel = FlutterMethodChannel(
      name: "roadway_native_navigation",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(RoadwayNativeNavigationPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "getCapabilities" else {
      result(FlutterMethodNotImplemented)
      return
    }
    result([
      "liquidGlass": Self.supportsLiquidGlass,
      "material3Expressive": false,
    ])
  }

  /// UIKit applies Liquid Glass on iOS 26+ when the app is built with the iOS 26
  /// SDK and has not opted out through `UIDesignRequiresCompatibility`.
  static var supportsLiquidGlass: Bool {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      let optedOut = Bundle.main.object(
        forInfoDictionaryKey: "UIDesignRequiresCompatibility"
      ) as? Bool ?? false
      return !optedOut
    }
    #endif
    return false
  }
}

private final class NativeNavigationBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeNavigationBarPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class NativeNavigationBarPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let tabBar: UITabBar
  private let channel: FlutterMethodChannel
  private var itemCount = 0

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    tabBar = UITabBar(frame: frame)
    channel = FlutterMethodChannel(
      name: "roadway_native_navigation/navigation_bar/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    tabBar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    tabBar.delegate = self
    guard setItems(arguments) else {
      preconditionFailure("Native navigation received invalid creation parameters.")
    }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "setSelectedIndex":
      guard let index = call.arguments as? Int, isValid(index) else {
        result(FlutterError(
          code: "invalid-selection",
          message: "The native navigation item index is invalid.",
          details: nil
        ))
        return
      }
      if tabBar.selectedItem?.tag != index {
        tabBar.selectedItem = tabBar.items?[index]
      }
      result(nil)
    case "setItems":
      guard setItems(call.arguments) else {
        result(FlutterError(
          code: "invalid-items",
          message: "The native navigation items are invalid.",
          details: nil
        ))
        return
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Replaces the tab bar items. Returns `false` when the arguments are invalid.
  private func setItems(_ arguments: Any?) -> Bool {
    guard
      let values = arguments as? [String: Any],
      let items = values["items"] as? [[String: Any]],
      !items.isEmpty,
      items.count <= 5,
      let selectedIndex = values["selectedIndex"] as? Int,
      items.indices.contains(selectedIndex)
    else {
      return false
    }

    let tabBarItems = items.enumerated().map { index, item in
      UITabBarItem(
        title: item["label"] as? String,
        image: item.iconImage,
        tag: index
      )
    }
    tabBar.setItems(tabBarItems, animated: false)
    tabBar.selectedItem = tabBarItems[selectedIndex]
    itemCount = items.count
    return true
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView {
    tabBar
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("onItemSelected", arguments: item.tag)
  }

  private func isValid(_ index: Int) -> Bool {
    (0..<itemCount).contains(index)
  }
}

private enum NativeNavigationIcon: String {
  case home
  case search
  case favorites
  case profile

  var systemName: String {
    switch self {
    case .home: "house"
    case .search: "magnifyingglass"
    case .favorites: "star"
    case .profile: "person"
    }
  }
}

private extension Dictionary where Key == String, Value == Any {
  var iconImage: UIImage {
    if let imageData = (self["iconBytes"] as? FlutterStandardTypedData)?.data,
      let image = UIImage(data: imageData) {
      return image
        .scaledToFit(size: CGSize(width: 25, height: 25))
        .withRenderingMode(.alwaysTemplate)
    }

    guard
      let iconName = self["icon"] as? String,
      let icon = NativeNavigationIcon(rawValue: iconName),
      let image = UIImage(systemName: icon.systemName)
    else {
      preconditionFailure("The native navigation icon is invalid.")
    }
    return image
  }
}

private extension UIImage {
  func scaledToFit(size: CGSize) -> UIImage {
    let scale = min(size.width / self.size.width, size.height / self.size.height)
    let scaledSize = CGSize(
      width: self.size.width * scale,
      height: self.size.height * scale
    )
    let origin = CGPoint(
      x: (size.width - scaledSize.width) / 2,
      y: (size.height - scaledSize.height) / 2
    )
    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { _ in
      self.draw(in: CGRect(origin: origin, size: scaledSize))
    }
  }
}
