#ifndef FLUTTER_PLUGIN_TWILLIO_ANDROID_PLUGIN_H_
#define FLUTTER_PLUGIN_TWILLIO_ANDROID_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace twillio_android {

class TwillioAndroidPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  TwillioAndroidPlugin();

  virtual ~TwillioAndroidPlugin();

  // Disallow copy and assign.
  TwillioAndroidPlugin(const TwillioAndroidPlugin&) = delete;
  TwillioAndroidPlugin& operator=(const TwillioAndroidPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace twillio_android

#endif  // FLUTTER_PLUGIN_TWILLIO_ANDROID_PLUGIN_H_
