import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'twillio_android_platform_interface.dart';

/// An implementation of [TwillioAndroidPlatform] that uses method channels.
class MethodChannelTwillioAndroid extends TwillioAndroidPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('twillio_android');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
