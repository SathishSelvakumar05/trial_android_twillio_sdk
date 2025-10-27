# Keep all Twilio Video SDK classes
-keep class com.twilio.video.** { *; }

# Keep all WebRTC classes Twilio depends on
-keep class tvi.webrtc.** { *; }

# Keep inner class metadata (required for reflection)
-keepattributes InnerClasses
