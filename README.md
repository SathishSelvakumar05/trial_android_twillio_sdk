# Twillio Android Plugin

A Flutter plugin for Twilio Video integration on Android.

## 📸 Screenshots

| Screenshot 1 | Screenshot 2 |
|---------------|--------------|
| ![Sample 1](screenshots/video_img.jpg) | ![Sample 2](screenshots/video_img2.jpg) |

## 🚀 Features
- Join / Leave Room
- Handle Remote Participants
- Toggle Camera, Mic, Speaker, etc.

---

## 🧩 Permissions

Make sure to add the following permissions in your **Android** and **iOS** projects.

---

### 🟢 Android Permissions

Add these lines inside your **`android/app/src/main/AndroidManifest.xml`** file:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- Required for Android 13+ (Media Access) -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
