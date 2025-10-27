import 'package:flutter_test/flutter_test.dart';
import 'package:twillio_android/twillio_android.dart';
import 'package:twillio_android/twillio_android_platform_interface.dart';
import 'package:twillio_android/twillio_android_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTwillioAndroidPlatform
    with MockPlatformInterfaceMixin
    implements TwillioAndroidPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TwillioAndroidPlatform initialPlatform = TwillioAndroidPlatform.instance;

  test('$MethodChannelTwillioAndroid is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTwillioAndroid>());
  });

  test('getPlatformVersion', () async {
    TwillioAndroid twillioAndroidPlugin = TwillioAndroid();
    MockTwillioAndroidPlatform fakePlatform = MockTwillioAndroidPlatform();
    TwillioAndroidPlatform.instance = fakePlatform;

    expect(await twillioAndroidPlugin.getPlatformVersion(), '42');
  });
}
