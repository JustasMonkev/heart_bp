package com.example.heart_bp

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "heart_bp/home_widget"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateLatestReading" -> {
                    val values = call.arguments as? Map<*, *>
                    if (values == null) {
                        result.error("invalid_args", "Expected latest reading values.", null)
                        return@setMethodCallHandler
                    }

                    HeartBpWidgetProvider.saveLatestReading(this, values)
                    result.success(null)
                }
                "clearLatestReading" -> {
                    HeartBpWidgetProvider.clearLatestReading(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
