package com.example.heart_bp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class HeartBpWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        private const val PREFS_NAME = "heart_bp_home_widget"
        private const val KEY_HAS_READING = "has_reading"
        private const val KEY_SYSTOLIC = "systolic"
        private const val KEY_DIASTOLIC = "diastolic"
        private const val KEY_PULSE = "pulse"
        private const val KEY_CAPTURED_AT_MILLIS = "captured_at_millis"
        private const val KEY_LEVEL = "level"
        private const val KEY_LEVEL_LABEL = "level_label"

        fun saveLatestReading(context: Context, values: Map<*, *>) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_HAS_READING, true)
                .putInt(KEY_SYSTOLIC, (values["systolic"] as Number).toInt())
                .putInt(KEY_DIASTOLIC, (values["diastolic"] as Number).toInt())
                .putInt(KEY_PULSE, (values["pulse"] as Number).toInt())
                .putLong(KEY_CAPTURED_AT_MILLIS, (values["capturedAtMillis"] as Number).toLong())
                .putString(KEY_LEVEL, values["level"] as? String ?: "")
                .putString(KEY_LEVEL_LABEL, values["levelLabel"] as? String ?: "Reading")
                .apply()

            updateAll(context)
        }

        fun clearLatestReading(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().clear().apply()
            updateAll(context)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, HeartBpWidgetProvider::class.java))
            updateWidgets(context, manager, ids)
        }

        private fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray
        ) {
            for (appWidgetId in appWidgetIds) {
                appWidgetManager.updateAppWidget(appWidgetId, buildRemoteViews(context))
            }
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.heart_bp_widget)
            val launchIntent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            if (!prefs.getBoolean(KEY_HAS_READING, false)) {
                views.setTextViewText(R.id.widget_systolic, "--")
                views.setTextViewText(R.id.widget_diastolic, "--")
                views.setTextViewText(R.id.widget_time, "--:--")
                views.setTextViewText(R.id.widget_pulse, "-- bpm")
                views.setTextViewText(R.id.widget_stage, "Add a reading")
                views.setTextColor(R.id.widget_stage, Color.parseColor("#B8BED0"))
                return views
            }

            val systolic = prefs.getInt(KEY_SYSTOLIC, 0)
            val diastolic = prefs.getInt(KEY_DIASTOLIC, 0)
            val pulse = prefs.getInt(KEY_PULSE, 0)
            val capturedAtMillis = prefs.getLong(KEY_CAPTURED_AT_MILLIS, 0L)
            val level = prefs.getString(KEY_LEVEL, "") ?: ""
            val levelLabel = prefs.getString(KEY_LEVEL_LABEL, "Reading") ?: "Reading"
            val levelColor = colorForLevel(level)

            views.setTextViewText(R.id.widget_systolic, systolic.toString())
            views.setTextViewText(R.id.widget_diastolic, diastolic.toString())
            views.setTextViewText(R.id.widget_time, formatTime(capturedAtMillis))
            views.setTextViewText(R.id.widget_pulse, "$pulse bpm")
            views.setTextViewText(R.id.widget_stage, levelLabel)
            views.setTextColor(R.id.widget_stage, levelColor)

            return views
        }

        private fun formatTime(capturedAtMillis: Long): String {
            if (capturedAtMillis <= 0L) return "--:--"
            return SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(capturedAtMillis))
        }

        private fun colorForLevel(level: String): Int {
            return when (level) {
                "crisis" -> Color.parseColor("#D32F2F")
                "highStage2" -> Color.parseColor("#FF5A1F")
                "highStage1" -> Color.parseColor("#EF8B25")
                "elevated" -> Color.parseColor("#BF8F00")
                "normal" -> Color.parseColor("#2E8B57")
                "low" -> Color.parseColor("#4A78B8")
                else -> Color.parseColor("#B8BED0")
            }
        }
    }
}
