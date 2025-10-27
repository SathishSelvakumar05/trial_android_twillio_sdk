#include "include/twillio_android/twillio_android_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "twillio_android_plugin.h"

void TwillioAndroidPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  twillio_android::TwillioAndroidPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
