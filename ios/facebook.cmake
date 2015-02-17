set(fb_plugin_root "${CMAKE_CURRENT_LIST_DIR}")

# Frameworks to be copied
list(APPEND TEALEAF_PLUGIN_COPY_FRAMEWORKS
  "${fb_plugin_root}/FacebookSDK.framework")

# Add include paths
include_directories("${fb_plugin_root}/include")

# Source files
list(APPEND TEALEAF_PLUGIN_SRC "${fb_plugin_root}/src/FacebookPlugin.mm")
