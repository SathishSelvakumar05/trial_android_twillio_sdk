import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:twillio_android/twillio_android.dart';

void main() {
  runApp(const VideoCallScreen(roomName: "",accessToken: "",));
}


class VideoCallScreen extends StatefulWidget {
  final String accessToken;
  final String roomName;

  const VideoCallScreen({
    super.key,
    required this.accessToken,
    required this.roomName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
  bool isAudioMuted = false;
  bool isVideoMuted = false;

  List<String> remoteParticipants = [];
  Map<String, bool> participantAudioState = {};
  Map<String, bool> participantVideoState = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _connectToRoom();
    _listenForParticipants();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // optionally re-attach camera
    } else if (state == AppLifecycleState.paused) {
      // optionally pause video
    }
  }

  Future<void> _connectToRoom() async {
    try {
      await TwillioSDK.connect(widget.accessToken, widget.roomName);
      debugPrint("✅ Connected to room: ${widget.roomName}");
    } catch (e) {
      debugPrint("❌ Failed to connect: $e");
    }
  }

  void _listenForParticipants() {
    TwillioSDK.events.listen((event) {
      if (event is Map) {
        final eventType = event["event"];
        final identity = event["identity"];

        setState(() {
          switch (eventType) {
            case "participant_connected":
              if (!remoteParticipants.contains(identity)) {
                remoteParticipants.add(identity);
              }
              participantAudioState[identity] = true;
              participantVideoState[identity] = true;
              break;

            case "participant_disconnected":
              remoteParticipants.remove(identity);
              participantAudioState.remove(identity);
              participantVideoState.remove(identity);
              break;

            case "audio_enabled":
              participantAudioState[identity] = true;
              break;

            case "audio_disabled":
              participantAudioState[identity] = false;
              break;

            case "video_enabled":
              participantVideoState[identity] = true;
              break;

            case "video_disabled":
              participantVideoState[identity] = false;
              break;

            case "connected":
              debugPrint("✅ Room connected");
              break;

            case "disconnected":
              debugPrint("🛑 Disconnected from room");
              break;
          }
        });
      }
    });
  }

  Future<void> _toggleAudio() async {
    if (isAudioMuted) {
      await TwillioSDK.unmuteAudio();
    } else {
      await TwillioSDK.muteAudio();
    }
    setState(() => isAudioMuted = !isAudioMuted);
  }

  Future<void> _toggleVideo() async {
    if (isVideoMuted) {
      await TwillioSDK.enableVideo();
    } else {
      await TwillioSDK.disableVideo();
    }
    setState(() => isVideoMuted = !isVideoMuted);
  }

  Future<void> _switchCamera() async {
    await TwillioSDK.switchCamera();
  }

  Future<void> _endCall() async {
    await TwillioSDK.disconnect();
    if (mounted) Navigator.pop(context);
  }

  // --------------------- UI ---------------------

  Widget _buildRemoteGrid() {
    final count = remoteParticipants.length;
    final crossAxisCount = count <= 2 ? 1 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final identity = remoteParticipants[index];
        final isAudioOn = participantAudioState[identity] ?? true;
        final isVideoOn = participantVideoState[identity] ?? true;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: isVideoOn
                    ? AndroidView(
                  viewType: "RemoteVideoView",
                  creationParams: {"identity": identity},
                  creationParamsCodec: const StandardMessageCodec(),
                )
                    : Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white54, size: 48),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          identity,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(isAudioOn ? Icons.mic : Icons.mic_off,
                          color: isAudioOn ? Colors.greenAccent : Colors.redAccent),
                      const SizedBox(width: 6),
                      Icon(isVideoOn ? Icons.videocam : Icons.videocam_off,
                          color: isVideoOn ? Colors.greenAccent : Colors.redAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalPreview() {
    return Positioned(
      bottom: 110,
      right: 10,
      child: Container(
        height: 160,
        width: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: AndroidView(
          viewType: "LocalVideoView",
          creationParams: const {},
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 25,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(Icons.mic, _toggleAudio, isActive: isAudioMuted, activeColor: Colors.redAccent),
          _buildControlButton(Icons.videocam, _toggleVideo, isActive: isVideoMuted, activeColor: Colors.orangeAccent),
          _buildControlButton(Icons.switch_camera, _switchCamera, activeColor: Colors.blueAccent),
          _buildControlButton(Icons.call_end, _endCall, activeColor: Colors.red, isActive: true),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap,
      {bool isActive = false, Color activeColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? activeColor.withOpacity(0.8) : Colors.grey[800],
        ),
        padding: const EdgeInsets.all(14),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              _buildRemoteGrid(),
              _buildLocalPreview(),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }
}


// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//
//   @override
//   State<MyApp> createState() => _MyAppState();
// }
//
// class _MyAppState extends State<MyApp> {
//   String _platformVersion = 'Unknown';
//   // final _twillioAndroidPlugin = TwillioAndroid();
//
//   @override
//   void initState() {
//     super.initState();
//     initPlatformState();
//   }
//
//   // Platform messages are asynchronous, so we initialize in an async method.
//   Future<void> initPlatformState() async {
//     String platformVersion;
//     // Platform messages may fail, so we use a try/catch PlatformException.
//     // We also handle the message potentially returning null.
//     try {
//       platformVersion ="??";
//           // await _twillioAndroidPlugin.getPlatformVersion() ?? 'Unknown platform version';
//     } on PlatformException {
//       platformVersion = 'Failed to get platform version.';
//     }
//
//     // If the widget was removed from the tree while the asynchronous platform
//     // message was in flight, we want to discard the reply rather than calling
//     // setState to update our non-existent appearance.
//     if (!mounted) return;
//
//     setState(() {
//       _platformVersion = platformVersion;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(
//           title: const Text('Plugin example app'),
//         ),
//         body: Center(
//           child: Text('Running on: $_platformVersion\n'),
//         ),
//       ),
//     );
//   }
// }
