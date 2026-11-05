import 'package:flutter/services.dart';

class TvInputChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.xycz.simple_live_tv/input',
  );

  static Future<String?> show({
    String title = '输入',
    String hint = '',
    String initialText = '',
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('showInputDialog', {
        'title': title,
        'hint': hint,
        'initialText': initialText,
      });
      return result;
    } catch (e) {
      return null;
    }
  }
}
