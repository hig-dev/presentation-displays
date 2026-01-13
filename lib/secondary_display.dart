import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Only use a subscription to listen within the secondary display
/// [arguments] returned  type [dynamic]
typedef ArgumentsCallback = Function(dynamic arguments);

/// This widget will wrap the secondary display, it will receive data transmitted from [DisplayManager].
/// [SecondaryDisplay.callback] instance of [ArgumentsCallback] to receive data transmitted from the [DisplayManager].
/// [SecondaryDisplay.child] child widget of secondary display
class SecondaryDisplay extends StatefulWidget {
  const SecondaryDisplay({
    Key? key,
    required this.callback,
    required this.child,
  }) : super(key: key);

  /// instance of [ArgumentsCallback] to receive data transmitted from the [DisplaysManager].
  final ArgumentsCallback callback;

  /// Your Flutter UI on Presentation Screen
  final Widget child;

  @override
  _SecondaryDisplayState createState() => _SecondaryDisplayState();
}

class _SecondaryDisplayState extends State<SecondaryDisplay> {
  static const _presentationChannel = "presentation_displays_plugin_engine";
  late MethodChannel _presentationMethodChannel;

  @override
  void initState() {
    super.initState();
    _presentationMethodChannel = const MethodChannel(_presentationChannel);
    _presentationMethodChannel.setMethodCallHandler((call) async {
      // It's good practice to check the method name, even if there is only one for now
      if (call.method == "DataTransfer") {
        widget.callback(call.arguments);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}