import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 注册自定义 prefs channel
    if let controller = window?.rootViewController as? FlutterViewController {
      let prefsChannel = FlutterMethodChannel(name: "com.qialiao.app/prefs", binaryMessenger: controller.binaryMessenger)
      prefsChannel.setMethodCallHandler { (call, result) in
        let defaults = UserDefaults.standard
        let args = call.arguments as? [String: Any]
        let key = args?["key"] as? String

        switch call.method {
        case "getAll":
          let dict = defaults.dictionaryRepresentation()
          var filtered: [String: Any] = [:]
          for (k, v) in dict {
            if k.hasPrefix("flutter.") {
              let cleanKey = String(k.dropFirst(8))
              filtered[cleanKey] = v
            }
          }
          result(filtered)
        case "setString":
          if let k = key, let v = args?["value"] as? String {
            defaults.set(v, forKey: "flutter.\(k)")
            result(true)
          } else { result(false) }
        case "setInt":
          if let k = key, let v = args?["value"] as? Int {
            defaults.set(v, forKey: "flutter.\(k)")
            result(true)
          } else { result(false) }
        case "setBool":
          if let k = key, let v = args?["value"] as? Bool {
            defaults.set(v, forKey: "flutter.\(k)")
            result(true)
          } else { result(false) }
        case "setStringList":
          if let k = key, let v = args?["value"] as? [String] {
            defaults.set(v, forKey: "flutter.\(k)")
            result(true)
          } else { result(false) }
        case "remove":
          if let k = key {
            defaults.removeObject(forKey: "flutter.\(k)")
            result(true)
          } else { result(false) }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
