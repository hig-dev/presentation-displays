import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presentation_displays_hig/display.dart';
import 'package:presentation_displays_hig/displays_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Display Model Tests', () {
    test('Display.fromJson with explicit isBuiltin: true', () {
      final json = {
        'displayId': 1,
        'flags': 0,
        'rotation': 0,
        'name': 'Built-in Screen 1',
        'isBuiltin': true,
      };

      final display = Display.fromJson(json);
      expect(display.displayId, 1);
      expect(display.name, 'Built-in Screen 1');
      expect(display.isBuiltin, isTrue);
      expect(display.isExternal, isFalse);
    });

    test('Display.fromJson with explicit isBuiltin: false', () {
      final json = {
        'displayId': 2,
        'flags': 0,
        'rotation': 0,
        'name': 'Screen 2',
        'isBuiltin': false,
      };

      final display = Display.fromJson(json);
      expect(display.displayId, 2);
      expect(display.name, 'Screen 2');
      expect(display.isBuiltin, isFalse);
      expect(display.isExternal, isTrue);
    });

    test('Display.fromJson fallback when isBuiltin is omitted', () {
      final defaultJson = {
        'displayId': DEFAULT_DISPLAY,
        'flags': 0,
        'rotation': 0,
        'name': 'Built-in Screen',
      };
      final secondaryJson = {
        'displayId': 1,
        'flags': 0,
        'rotation': 0,
        'name': 'Screen 1',
      };

      final defaultDisplay = Display.fromJson(defaultJson);
      expect(defaultDisplay.isBuiltin, isTrue);
      expect(defaultDisplay.isExternal, isFalse);

      final secondaryDisplay = Display.fromJson(secondaryJson);
      expect(secondaryDisplay.isBuiltin, isFalse);
      expect(secondaryDisplay.isExternal, isTrue);
    });
  });

  group('DisplayManager Tests with Mock MethodChannel', () {
    const channel = MethodChannel('presentation_displays_plugin');
    late DisplayManager displayManager;

    final mockDisplaysData = [
      {
        'displayId': 0,
        'flags': 0,
        'rotation': 0,
        'name': 'Built-in Screen',
        'isBuiltin': true,
      },
      {
        'displayId': 1,
        'flags': 0,
        'rotation': 0,
        'name': 'Built-in Screen 1',
        'isBuiltin': true, // iPhone Duo secondary built-in display
      },
      {
        'displayId': 2,
        'flags': 0,
        'rotation': 0,
        'name': 'Screen 2',
        'isBuiltin': false, // External presentation display (HDMI / AirPlay)
      },
    ];

    setUp(() {
      displayManager = DisplayManager();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'listDisplay') {
          return jsonEncode(mockDisplaysData);
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('getDisplays(filter: DisplayFilter.all) returns all displays', () async {
      final displays = await displayManager.getDisplays(filter: DisplayFilter.all);
      expect(displays, isNotNull);
      expect(displays!.length, 3);
      expect(displays[0].displayId, 0);
      expect(displays[1].displayId, 1);
      expect(displays[2].displayId, 2);
    });

    test('getDisplays(filter: DisplayFilter.externalOnly) filters out both built-in screens', () async {
      final displays = await displayManager.getDisplays(filter: DisplayFilter.externalOnly);
      expect(displays, isNotNull);
      expect(displays!.length, 1);
      expect(displays.first.displayId, 2);
      expect(displays.first.name, 'Screen 2');
      expect(displays.first.isExternal, isTrue);
      expect(displays.first.isBuiltin, isFalse);
    });

    test('getDisplays(filter: DisplayFilter.builtinOnly) returns both built-in screens', () async {
      final displays = await displayManager.getDisplays(filter: DisplayFilter.builtinOnly);
      expect(displays, isNotNull);
      expect(displays!.length, 2);
      expect(displays[0].displayId, 0);
      expect(displays[1].displayId, 1);
      expect(displays[0].isBuiltin, isTrue);
      expect(displays[1].isBuiltin, isTrue);
    });

    test('getNameByDisplayId with filter', () async {
      final nameExternal = await displayManager.getNameByDisplayId(
        2,
        filter: DisplayFilter.externalOnly,
      );
      expect(nameExternal, 'Screen 2');

      final nameBuiltinExcluded = await displayManager.getNameByDisplayId(
        1,
        filter: DisplayFilter.externalOnly,
      );
      expect(nameBuiltinExcluded, isNull);
    });

    test('getNameByIndex with filter', () async {
      final firstNameAll = await displayManager.getNameByIndex(0, filter: DisplayFilter.all);
      expect(firstNameAll, 'Built-in Screen');

      final firstNameExternal = await displayManager.getNameByIndex(0, filter: DisplayFilter.externalOnly);
      expect(firstNameExternal, 'Screen 2');
    });
  });
}
