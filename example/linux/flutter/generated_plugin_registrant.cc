//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <twillio_android/twillio_android_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) twillio_android_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "TwillioAndroidPlugin");
  twillio_android_plugin_register_with_registrar(twillio_android_registrar);
}
