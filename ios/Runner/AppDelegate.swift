import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var deviceToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      // APNs device token channel
      let apnsChannel = FlutterMethodChannel(name: "com.qialiao.app/apns", binaryMessenger: controller.binaryMessenger)
      apnsChannel.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "getDeviceToken":
          result(self?.deviceToken)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // Prefs channel
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

  // 收到 APNs device token
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    self.deviceToken = token
    print("[APNs] Device token: \(token)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("[APNs] Failed to register: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
