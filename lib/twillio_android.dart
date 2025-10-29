
import 'package:flutter/services.dart';

class TwillioSDK {
  static const MethodChannel _channel = MethodChannel('twilio_video');
  static const EventChannel _events = EventChannel('twilio_video_events');

  static Future<void> connect(String token, String room) async {
    await _channel.invokeMethod('connectToRoom', {'token': token, 'roomName': room});
  }

  static Future<void> disconnect() async => _channel.invokeMethod('disconnect');
  static Future<void> muteAudio() async => _channel.invokeMethod('muteAudio');
  static Future<void> unmuteAudio() async => _channel.invokeMethod('unmuteAudio');
  static Future<void> enableVideo() async => _channel.invokeMethod('enableVideo');
  static Future<void> disableVideo() async => _channel.invokeMethod('disableVideo');
  static Future<void> switchCamera() async => _channel.invokeMethod('switchCamera');
  static Future<void> toggleSpeaker(bool enable) async {
    await _channel.invokeMethod('toggleSpeaker', {'enable': enable});
  }

  static Stream<Map<dynamic, dynamic>> get events =>
      _events.receiveBroadcastStream().cast<Map<dynamic, dynamic>>();
}

