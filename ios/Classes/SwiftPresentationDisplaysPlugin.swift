import Flutter
import UIKit

public class SwiftPresentationDisplaysPlugin: NSObject, FlutterPlugin {
    var additionalWindows = [UIScreen: UIWindow]()
    var screens = [UIScreen]()
    var flutterEngineChannel: FlutterMethodChannel? = nil
    
    // Callback to register plugins on the new engine
    public static var controllerAdded: ((FlutterViewController) -> Void)?

    public override init() {
        super.init()
        screens.append(UIScreen.main)
        startObservingLifecycle()
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "presentation_displays_plugin", binaryMessenger: registrar.messenger())
        let instance = SwiftPresentationDisplaysPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "presentation_displays_plugin_events", binaryMessenger: registrar.messenger())
        let displayConnectedStreamHandler = DisplayConnectedStreamHandler()
        eventChannel.setStreamHandler(displayConnectedStreamHandler)
    }

    private func startObservingLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidConnect),
            name: UIScene.willConnectNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidDisconnect),
            name: UIScreen.didDisconnectNotification,
            object: nil
        )
    }

    @objc private func sceneDidConnect(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene else { return }
        
        // Ensure this scene corresponds to an external screen
        let screen = scene.screen
        if screen == UIScreen.main { return }
        
        createWindow(for: screen, withScene: scene)
    }

    @objc private func screenDidDisconnect(_ notification: Notification) {
        guard let screen = notification.object as? UIScreen else { return }
        
        // Remove from internal list
        if let index = self.screens.firstIndex(of: screen) {
            self.screens.remove(at: index)
        }
        
        // Teardown the window
        if let window = self.additionalWindows[screen] {
            window.isHidden = true
            window.windowScene = nil // Detach from scene
            self.additionalWindows.removeValue(forKey: screen)
        }
    }

    private func createWindow(for screen: UIScreen, withScene scene: UIWindowScene) {
        if self.additionalWindows[screen] != nil { return }

        // Create the window attached to the scene
        let newWindow = UIWindow(windowScene: scene)
        newWindow.isHidden = true

        self.screens.append(screen)
        self.additionalWindows[screen] = newWindow
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "listDisplay":
            handleListDisplay(result: result)
        case "showPresentation":
            if let args = call.arguments as? [String: Any] {
                showPresentation(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a Map<String, Any>", details: nil))
            }
        case "hidePresentation":
            if let args = call.arguments as? [String: Any] {
                hidePresentation(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a Map<String, Any>", details: nil))
            }
        case "transferDataToPresentation":
            self.flutterEngineChannel?.invokeMethod("DataTransfer", arguments: call.arguments)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleListDisplay(result: FlutterResult) {
        var displays = [[String: Any]]()
        
        for (index, _) in screens.enumerated() {
            let name = (index == 0) ? "Built-in Screen" : "Screen \(index)"
            displays.append([
                "displayId": index,
                "name": name
            ])
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: displays, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)
            result(jsonString)
        } catch {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to encode displays", details: nil))
        }
    }
    
    private func showPresentation(args: [String: Any], result: FlutterResult) {
        let displayId = args["displayId"] as? Int ?? 1
        let routerName = args["routerName"] as? String ?? "presentation"
        
        performShowPresentation(index: displayId, routerName: routerName)
        result(true)
    }
    
    private func hidePresentation(args: [String: Any], result: FlutterResult) {
        let displayId = args["displayId"] as? Int ?? 1
        performHidePresentation(index: displayId)
        result(true)
    }

    private func performShowPresentation(index: Int, routerName: String) {
        guard index > 0, index < self.screens.count else { return }
        
        let screen = self.screens[index]
        
        // Check if the window/scene is ready
        guard let window = self.additionalWindows[screen] else {
            print("[PresentationDisplays] Window not found for screen index \(index). The UIScene might not be connected yet.")
            return
        }

        // Only create a new engine if one doesn't exist or isn't a FlutterVC
        if window.rootViewController == nil || !(window.rootViewController is FlutterViewController) {
            window.isHidden = false
            
            let flutterEngine = FlutterEngine(name: "secondary_display_engine")
            flutterEngine.run(withEntrypoint: "secondaryDisplayMain", initialRoute: routerName)
            
            let extVC = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
            SwiftPresentationDisplaysPlugin.controllerAdded?(extVC)
            
            window.rootViewController = extVC
            self.flutterEngineChannel = FlutterMethodChannel(name: "presentation_displays_plugin_engine", binaryMessenger: extVC.binaryMessenger)
        } else {
             window.isHidden = false
        }
    }

    private func performHidePresentation(index: Int) {
        guard index > 0, index < self.screens.count else { return }
        
        let screen = self.screens[index]
        if let window = self.additionalWindows[screen] {
            window.isHidden = true
        }
    }
}

class DisplayConnectedStreamHandler: NSObject, FlutterStreamHandler {
    var sink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        NotificationCenter.default.addObserver(self, selector: #selector(screenDidConnect), name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenDidDisconnect), name: UIScreen.didDisconnectNotification, object: nil)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        NotificationCenter.default.removeObserver(self)
        return nil
    }
    
    @objc func screenDidConnect() { sink?(1) }
    @objc func screenDidDisconnect() { sink?(0) }
}
