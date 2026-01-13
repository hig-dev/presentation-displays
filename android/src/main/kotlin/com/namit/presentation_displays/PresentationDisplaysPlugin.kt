package com.namit.presentation_displays

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import com.google.gson.Gson
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** PresentationDisplaysPlugin */
class PresentationDisplaysPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

  private lateinit var channel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var flutterEngineChannel: MethodChannel? = null
  private var context: Context? = null
  private var displayManager: DisplayManager? = null
  private var presentation: PresentationDisplay? = null

  companion object {
    private const val VIEW_TYPE_ID = "presentation_displays_plugin"
    private const val VIEW_TYPE_EVENTS_ID = "presentation_displays_plugin_events"
    private const val TAG = "PresentationDisplay"
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, VIEW_TYPE_ID)
    channel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, VIEW_TYPE_EVENTS_ID)

    displayManager = flutterPluginBinding.applicationContext.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager

    val displayConnectedStreamHandler = DisplayConnectedStreamHandler(displayManager)
    eventChannel.setStreamHandler(displayConnectedStreamHandler)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    Log.d(TAG, "Method: ${call.method} | Args: ${call.arguments}")

    when (call.method) {
      "showPresentation" -> handleShowPresentation(call.arguments, result)
      "hidePresentation" -> handleHidePresentation(call.arguments, result)
      "listDisplay" -> handleListDisplay(call.arguments, result)
      "transferDataToPresentation" -> {
        try {
          flutterEngineChannel?.invokeMethod("DataTransfer", call.arguments)
          result.success(true)
        } catch (e: Exception) {
          result.error("TRANSFER_ERROR", e.message, null)
        }
      }
      else -> result.notImplemented()
    }
  }


  private fu// Support both Map (New) and JSON String (Legacy)
  val (displayId, routerName) = parseShowArgs(arguments)n handleShowPresentation(arguments: Any?, result: MethodChannel.Result) {
    try {
      val id = args["displayId"] as? Int ?: 0
      val route = args["routerName"] as? String ?: "/"

      val display = displayManager?.getDisplay(displayId)
      if (display != null) {
        // Create or retrieve the engine for the secondary display
        val flutterEngine = createFlutterEngine(routerName)

        if (flutterEngine != null) {
          flutterEngineChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "${VIEW_TYPE_ID}_engine"
          )

          // Dismiss previous presentation if it exists to avoid overlaps
          presentation?.dismiss()

          // Create and show new presentation
          context?.let { ctx ->
            presentation = PresentationDisplay(ctx, routerName, display)
            presentation?.show()
            result.success(true)
          } ?: result.error("NO_CONTEXT", "Activity context is null", null)
        } else {
          result.error("ENGINE_ERROR", "Could not create FlutterEngine", null)
        }
      } else {
        result.error("404", "Can't find display with displayId $displayId", null)
      }
    } catch (e: Exception) {
      result.error("SHOW_ERROR", e.message, null)
    }
  }

  private fun handleHidePresentation(arguments: Any?, result: MethodChannel.Result) {
    try {
      // We don't strictly need arguments to hide the current presentation,
      // but we parse them to validate the call structure if needed.
      presentation?.dismiss()
      presentation = null
      result.success(true)
    } catch (e: Exception) {
      result.error("HIDE_ERROR", e.message, null)
    }
  }

  private fun handleListDisplay(categoryArg: Any?, result: MethodChannel.Result) {
    val listJson = ArrayList<DisplayJson>()
    val category = categoryArg as? String

    val displays = displayManager?.getDisplays(category)
    displays?.forEach { display ->
      listJson.add(
        DisplayJson(
          displayId = display.displayId,
          flags = display.flags,
          rotation = display.rotation,
          name = display.name
        )
      )
    }
    result.success(Gson().toJson(listJson))
  }

  private fun createFlutterEngine(tag: String): FlutterEngine? {
    val currentContext = context ?: return null

    // Return existing cached engine if available
    FlutterEngineCache.getInstance().get(tag)?.let { return it }

    // Create new engine
    val flutterEngine = FlutterEngine(currentContext)
    flutterEngine.navigationChannel.setInitialRoute(tag)

    FlutterInjector.instance().flutterLoader().startInitialization(currentContext)
    val path = FlutterInjector.instance().flutterLoader().findAppBundlePath()
    val entrypoint = DartExecutor.DartEntrypoint(path, "secondaryDisplayMain")

    flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)
    flutterEngine.lifecycleChannel.appIsResumed()

    FlutterEngineCache.getInstance().put(tag, flutterEngine)
    return flutterEngine
  }


  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.context = binding.activity
  }

  override fun onDetachedFromActivity() {
    // Dismiss presentation when activity is destroyed to prevent leaks
    presentation?.dismiss()
    presentation = null
    this.context = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    this.context = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    this.context = null
  }
}

// MARK: - Stream Handler

class DisplayConnectedStreamHandler(private val displayManager: DisplayManager?) : EventChannel.StreamHandler {
  private var sink: EventChannel.EventSink? = null
  private var handler: Handler? = null

  private val displayListener = object : DisplayManager.DisplayListener {
    override fun onDisplayAdded(displayId: Int) {
      sink?.success(1)
    }

    override fun onDisplayRemoved(displayId: Int) {
      sink?.success(0)
    }

    override fun onDisplayChanged(displayId: Int) {}
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
    handler = Handler(Looper.getMainLooper())
    displayManager?.registerDisplayListener(displayListener, handler)
  }

  override fun onCancel(arguments: Any?) {
    sink = null
    handler = null
    displayManager?.unregisterDisplayListener(displayListener)
  }
}