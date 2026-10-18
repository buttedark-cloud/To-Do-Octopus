import 'package:flutter/services.dart';

class BatteryOptimizationService {
  BatteryOptimizationService._();
  static final BatteryOptimizationService instance =
      BatteryOptimizationService._();

  static const _channel = MethodChannel('com.example.to_do/battery');

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Отдельное от батареи разрешение, которое есть только у MIUI
  Future<void> openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } catch (_) {}
  }
}
