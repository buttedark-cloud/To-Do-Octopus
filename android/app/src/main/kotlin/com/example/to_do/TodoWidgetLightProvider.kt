package com.example.to_do // ЗАМЕНИ на реальный package — как в MainActivity.kt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Светлая версия виджета — просто картинка (frame1.png -> res/drawable/frame1),
 * без каких-либо данных о задачах. Тап по любому месту открывает приложение.
 *
 * Раньше наследовался от HomeWidgetProvider (пакет home_widget) — он был
 * нужен, пока виджет получал живые данные из Dart. Теперь виджет полностью
 * статичный, и пакет home_widget тут ни для чего не нужен — используем
 * обычный AppWidgetProvider из самого Android, без сторонних зависимостей
 * (заодно избавляемся от одного из двух предупреждений про
 * "Kotlin Gradle Plugin (KGP)" при сборке — оно было как раз из-за этого
 * пакета).
 */
class TodoWidgetLightProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_todo_light)

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
