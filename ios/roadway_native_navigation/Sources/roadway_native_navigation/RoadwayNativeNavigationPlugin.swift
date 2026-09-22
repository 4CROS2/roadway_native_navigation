import Flutter
import UIKit

public class RoadwayNativeNavigationPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeNavigationBarFactory(messenger: registrar.messenger()),
      withId: "roadway_native_navigation/navigation_bar"
    )
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
  private let itemCount: Int

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    guard
      let values = arguments as? [String: Any],
      let items = values["items"] as? [[String: Any]],
      !items.isEmpty,
      items.count <= 5,
      let selectedIndex = values["selectedIndex"] as? Int,
      items.indices.contains(selectedIndex)
    else {
      preconditionFailure("Native navigation received invalid creation parameters.")
    }

    tabBar = UITabBar(frame: frame)
    itemCount = items.count
    channel = FlutterMethodChannel(
      name: "roadway_native_navigation/navigation_bar/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    tabBar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    tabBar.delegate = self
    tabBar.items = items.enumerated().map { index, item in
      UITabBarItem(
        title: item["label"] as? String,
        image: item.iconImage,
        tag: index
      )
    }
    tabBar.selectedItem = tabBar.items?[selectedIndex]
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setSelectedIndex" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let index = call.arguments as? Int, self?.isValid(index) == true else {
        result(FlutterError(
          code: "invalid-selection",
          message: "The native navigation item index is invalid.",
          details: nil
        ))
        return
      }
      if self?.tabBar.selectedItem?.tag != index {
        self?.tabBar.selectedItem = self?.tabBar.items?[index]
      }
      result(nil)
    }
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
