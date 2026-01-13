# presentation_displays

A Flutter plugin to manage and display content on secondary screens (HDMI, Wireless, AirPlay).

This plugin creates a separate `FlutterEngine` for the secondary display, allowing you to render a completely independent UI on the external screen while communicating with the main application via Method Channels.

## Features

* **Multi-Screen Support:** Run a separate Flutter widget tree on an external display.
* **Plug & Play:** Automatically detects connected displays.
* **Data Transfer:** Send data objects (Map/JSON) from the main screen to the secondary screen.
* **Cross-Platform:** Supports Android and iOS.

---

## 1. Flutter Setup (Entry Points)

To run a UI on a secondary screen, you must define a specific entry point called `secondaryDisplayMain`. This acts as the "main" function for your external display.

**In your `lib/main.dart` (or wherever your entry points are defined):**

```dart
import 'package:flutter/material.dart';

// 1. The Main Entry Point
void main() {
  debugPrint('first main');
  runApp(const MyApp());
}

// 2. The Secondary Entry Point
// IMPORTANT: This must be named 'secondaryDisplayMain' and annotated with @pragma('vm:entry-point')
@pragma('vm:entry-point')
void secondaryDisplayMain() {
  debugPrint('second main');
  runApp(const MySecondApp());
}

// 3. Your Secondary App Widget
class MySecondApp extends StatelessWidget {
  const MySecondApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      // Define specific routes for the secondary screen
      onGenerateRoute: generateRoute, 
      initialRoute: 'presentation',
    );
  }
}

// 4. Your Main App Widget
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      onGenerateRoute: generateRoute,
      initialRoute: '/',
    );
  }
}

```

---

## 2. Android Setup

No special configuration is required for Android. Ensure your `minSdkVersion` is compatible with Flutter defaults.

---

## 3. iOS Setup

**⚠️ Critical:** This plugin requires **iOS 13.0+** and the adoption of the **UIScene Lifecycle**. If your app is still using the legacy `UIWindow` logic without Scenes, it must be migrated.

### Step A: Update `Info.plist`

Open `ios/Runner/Info.plist` and add the `UIApplicationSceneManifest`. This configures the app to handle both the main application screen and the external display role.

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneClassName</key>
                <string>UIWindowScene</string>
                <key>UISceneDelegateClassName</key>
                <string>FlutterSceneDelegate</string>
                <key>UISceneConfigurationName</key>
                <string>flutter</string>
                <key>UISceneStoryboardFile</key>
                <string>Main</string>
            </dict>
        </array>
        
        <key>UIWindowSceneSessionRoleExternalDisplay</key>
        <array>
            <dict>
                <key>UISceneClassName</key>
                <string>UIWindowScene</string>
                <key>UISceneConfigurationName</key>
                <string>External Display</string>
                <key>UISceneDelegateClassName</key>
                <string>FlutterSceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>

```

### Step B: Update `AppDelegate.swift`

You must adopt the `FlutterImplicitEngineDelegate` protocol to handle plugin registration for the main engine, and hook into `SwiftPresentationDisplaysPlugin` to register plugins for the secondary engine.

Replace your `AppDelegate.swift` content with:

```swift
import UIKit
import Flutter
import presentation_displays_hig

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - FlutterImplicitEngineDelegate
  // This method is called when the main Flutter engine is initialized
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Register plugins for the MAIN engine
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    
    // Assign the callback for when the SECONDARY controller is added
    SwiftPresentationDisplaysPlugin.controllerAdded = controllerAdded
  }

  // This method is called by the plugin when the secondary display is connected
  func controllerAdded(controller: FlutterViewController) {
    // Register plugins for the SECONDARY engine
    GeneratedPluginRegistrant.register(with: controller)
  }
}

```

---

## Usage

### 1. Initialize Display Manager

```dart
import 'package:presentation_displays_hig/displays_manager.dart';

DisplayManager displayManager = DisplayManager();

```

### 2. List Connected Displays

```dart
List<Display> displays = [];

Future<void> getDisplays() async {
    final values = await displayManager.getDisplays();
    if (values != null) {
        setState(() {
            displays = values;
        });
    }
}

```

### 3. Show Presentation

Use the `displayId` from the list above and the `routerName` defined in your `MySecondApp` widget.

```dart
// Index 0 is usually the built-in screen, Index 1 is the external display
if (displays.length > 1) {
    await displayManager.showSecondaryDisplay(
        displayId: displays[1].displayId!, 
        routerName: "presentation"
    );
}

```

### 4. Transfer Data

You can send `Map` or `JSON` data to the secondary screen.

```dart
await displayManager.transferDataToPresentation({
    "title": "Customer Order",
    "total": 150.00,
    "items": ["Apple", "Banana"]
});

```

### 5. Receive Data (Secondary Screen)

In the widget running on the secondary screen (e.g., `SecondaryDisplay`), use the callback to receive data.

```dart
@override
Widget build(BuildContext context) {
  return SecondaryDisplay(
    callback: (argument) {
      // argument contains the Map/Data sent from the main screen
      setState(() {
        receivedData = argument;
      });
    },
    child: YourCustomWidget(data: receivedData),
  );
}

```

### 6. Hide Presentation

```dart
await displayManager.hideSecondaryDisplay(displayId: displays[1].displayId!);

```

