# Twillio Android Plugin

A Flutter plugin for Twilio Video integration on Android.

## Screenshots

| Screenshot 1 | Screenshot 2 |
|---------------|--------------|
| ![Sample 1](https://github.com/SathishSelvakumar05/trial_android_twillio_sdk/blob/9722ade133fb94773a2e135052c9d0fe5b2208c0/screenshots/sample_img.jpg) | ![Sample 2](https://github.com/SathishSelvakumar05/trial_android_twillio_sdk/blob/9722ade133fb94773a2e135052c9d0fe5b2208c0/screenshots/sample2.png) |

## Features
- Join / Leave Room
- Handle Remote Participants
- Toggle Camera, Mic, etc.

## ⚙️ Required Android Permissions

Make sure to add the following permissions inside your **`AndroidManifest.xml`** file:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- Required for Android 13+ (Media Access) -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
