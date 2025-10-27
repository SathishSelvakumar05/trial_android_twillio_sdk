import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'twillio_android_method_channel.dart';

abstract class TwillioAndroidPlatform extends PlatformInterface {
  /// Constructs a TwillioAndroidPlatform.
  TwillioAndroidPlatform() : super(token: _token);

  static final Object _token = Object();

  static TwillioAndroidPlatform _instance = MethodChannelTwillioAndroid();

  /// The default instance of [TwillioAndroidPlatform] to use.
  ///
  /// Defaults to [MethodChannelTwillioAndroid].
  static TwillioAndroidPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TwillioAndroidPlatform] when
  /// they register themselves.
  static set instance(TwillioAndroidPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
