package com.example.to_do // ЗАМЕНИ на реальный package — как в MainActivity.kt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Тёмная версия виджета — просто картинка (frame2.png -> res/drawable/frame2),
 * без каких-либо данных о задачах. Тап по любому месту открывает приложение.
 *
 * Как и у светлого виджета — раньше наследовался от HomeWidgetProvider
 * (пакет home_widget), теперь просто AppWidgetProvider из Android SDK,
 * без стороннего пакета.
 */
class TodoWidgetDarkProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_todo_dark)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
