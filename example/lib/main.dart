import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:twillio_android/twillio_android.dart';

void main() {
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VideoCallScreen(
                    roomName: "",
                    accessToken: "",)),
                );
              },
              child: Text("Start Call"),
            ),
          ),
        ),
      ),
    );
  }
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
  bool isSpeakerOn = true;


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

              _showConnectionStatus(
                message: "$identity joined the room",
                color: Colors.blueAccent,
                icon: Icons.person_add_alt_1,
              );
              break;

            case "participant_disconnected":
              remoteParticipants.remove(identity);
              participantAudioState.remove(identity);
              participantVideoState.remove(identity);

              _showConnectionStatus(
                message: "$identity left the room",
                color: Colors.redAccent,
                icon: Icons.exit_to_app,
              );
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
            case "room_disconnected":
            // 🟢 Handle disconnection event from native side
              _handleRoomDisconnected(event);
              break;
            case "connection_failed":
            // 🟢 Handle connection_failed event from native side for token expired etc
              _showConnectionStatus(
                message: "${event["error"]??"Failed to connect"}",
                color: Colors.red,
                icon: Icons.error_outline,
                showToastLonger: true
              );
              break;

          // 🟡 NEW: Handle network reconnecting/reconnected events
            case "reconnecting":
              _showConnectionStatus(
                message: "Network issue... Please wait",
                color: Colors.orangeAccent,
                icon: Icons.wifi_off,
                  showToastLonger:true
              );
              break;

            case "reconnected":
              _showConnectionStatus(
                message: "Reconnected successfully",
                color: Colors.greenAccent,
                icon: Icons.wifi,
              );
              break;
          }
        });
      }
    });
  }
  void _handleRoomDisconnected(Map event) {
    final roomName = event["room"];
    print("Room disconnected: $roomName");

    // Optional: show a snackbar or dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Disconnected from room $roomName"),
        backgroundColor: Colors.redAccent,
      ),
    );

    // Small delay so user can see the message, then pop
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
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
  Future<void> _toggleSpeaker() async {
    await TwillioSDK.toggleSpeaker(isSpeakerOn);

    setState(() => isSpeakerOn = !isSpeakerOn);
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
              // 🎥 Video view
              Positioned.fill(
                child: isVideoOn
                    ? AndroidView(
                  viewType: "RemoteVideoView",
                  creationParams: {"identity": identity},
                  creationParamsCodec: const StandardMessageCodec(),
                )
                    : Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: Icon(Icons.videocam_off,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),

              // 🧍 Participant info footer
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          identity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isAudioOn ? Icons.mic : Icons.mic_off,
                        color: isAudioOn ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isVideoOn ? Icons.videocam : Icons.videocam_off,
                        color: isVideoOn ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              // ✨ Subtle border glow for active video
              if (isAudioOn && isVideoOn)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 1.5),
                      borderRadius: BorderRadius.circular(16),
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
        padding: EdgeInsets.all(2),
        height: 160,
        width: 120,
        decoration: BoxDecoration(
          border: Border.all(color: !remoteParticipants.isNotEmpty?Colors.green:Colors.white, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: AndroidView(clipBehavior: Clip.antiAliasWithSaveLayer,
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

          _buildControlButton(Icons.volume_up, _toggleSpeaker, isActive: isSpeakerOn, activeColor: Colors.blue),
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
    return  Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildRemoteGrid(),
            _buildLocalPreview(),
            _buildControls(),
          ],
        ),
      ),);

  }
  void _showConnectionStatus({
    required String message,
    required Color color,
    required IconData icon,
    bool showToastLonger=false
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar(); // hide any existing message

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration:  Duration(seconds:showToastLonger==true?10: 3),
      ),
    );
  }
}

