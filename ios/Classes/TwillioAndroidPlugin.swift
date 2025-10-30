import Flutter
import UIKit
import TwilioVideo

public class TwillioIosPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var room: Room?
    private var localVideoTrack: LocalVideoTrack?
    private var localAudioTrack: LocalAudioTrack?
    private var camera: CameraSource?
    private var localVideoView: VideoView?

    private var remoteViews: [String: VideoView] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = TwillioIosPlugin()
        instance.methodChannel = FlutterMethodChannel(name: "twilio_video", binaryMessenger: registrar.messenger())
        instance.eventChannel = FlutterEventChannel(name: "twilio_video_events", binaryMessenger: registrar.messenger())

        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
        instance.eventChannel?.setStreamHandler(instance)

        registrar.register(LocalVideoViewFactory(), withId: "LocalVideoView")
        registrar.register(RemoteVideoViewFactory(), withId: "RemoteVideoView")
    }
}

// MARK: - Method Handling
extension TwillioIosPlugin: FlutterStreamHandler, FlutterPlugin {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connectToRoom":
            guard let args = call.arguments as? [String: Any],
                  let token = args["token"] as? String else {
                result(FlutterError(code: "ARG_NULL", message: "Missing token", details: nil))
                return
            }
            connectToRoom(token: token)
            result("Connecting to room")

        case "toggleSpeaker":
            let enable = (call.arguments as? [String: Any])?["enable"] as? Bool ?? false
            toggleSpeaker(enable: enable)
            result("Speaker \(enable ? "ON" : "OFF")")

        case "muteAudio":
            localAudioTrack?.isEnabled = false
            result(nil)

        case "unmuteAudio":
            localAudioTrack?.isEnabled = true
            result(nil)

        case "disableVideo":
            localVideoTrack?.removeRenderer(localVideoView!)
            localVideoTrack = nil
            result(nil)

        case "enableVideo":
            startLocalVideo()
            result(nil)

        case "switchCamera":
            switchCamera()
            result(nil)

        case "disconnect":
            room?.disconnect()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Twilio Room Connection
extension TwillioIosPlugin {
    private func connectToRoom(token: String) {
        startLocalVideo()
        localAudioTrack = LocalAudioTrack(options: nil, enabled: true, name: "Mic")

        let connectOptions = ConnectOptions(token: token) { builder in
            if let audio = self.localAudioTrack {
                builder.audioTracks = [audio]
            }
            if let video = self.localVideoTrack {
                builder.videoTracks = [video]
            }
        }

        room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
    }

    private func startLocalVideo() {
        camera = CameraSource(delegate: self)
        localVideoTrack = LocalVideoTrack(source: camera!, enabled: true, name: "Camera")
        if let frontCamera = CameraSource.captureDevice(position: .front) {
            camera!.startCapture(device: frontCamera) { _, _, error in
                if let err = error {
                    print("Camera start error: \(err.localizedDescription)")
                }
            }
        }
        localVideoView = LocalVideoViewFactory.currentView?.videoView
        localVideoTrack?.addRenderer(localVideoView!)
    }

    private func switchCamera() {
        guard let camera = camera else { return }
        let newPos: AVCaptureDevice.Position = (camera.device?.position == .front) ? .back : .front
        if let newDevice = CameraSource.captureDevice(position: newPos) {
            camera.selectCaptureDevice(newDevice) { _, _, error in
                if let e = error {
                    print("Camera switch error: \(e.localizedDescription)")
                }
            }
        }
    }

    private func toggleSpeaker(enable: Bool) {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setMode(.videoChat)
        try? audioSession.overrideOutputAudioPort(enable ? .speaker : .none)
        try? audioSession.setActive(true)
    }
}

// MARK: - Room Delegate
extension TwillioIosPlugin: RoomDelegate {
    public func roomDidConnect(room: Room) {
        eventSink?(["event": "room_connected", "room": room.name])
        for participant in room.remoteParticipants {
            participant.delegate = self
        }
    }

    public func roomDidDisconnect(room: Room, error: Error?) {
        eventSink?(["event": "room_disconnected", "room": room.name])
        self.room = nil
    }

    public func roomDidFailToConnect(room: Room, error: Error) {
        eventSink?(["event": "connection_failed", "error": error.localizedDescription])
    }

    public func participantDidConnect(room: Room, participant: RemoteParticipant) {
        eventSink?(["event": "participant_connected", "identity": participant.identity])
        participant.delegate = self
    }

    public func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        eventSink?(["event": "participant_disconnected", "identity": participant.identity])
    }
}

// MARK: - Remote Participant Delegate
extension TwillioIosPlugin: RemoteParticipantDelegate {
    public func remoteParticipant(_ participant: RemoteParticipant, publishedVideoTrack publication: RemoteVideoTrackPublication) {
        eventSink?(["event": "video_published", "identity": participant.identity])
    }

    public func remoteParticipant(_ participant: RemoteParticipant, subscribedTo videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication) {
        DispatchQueue.main.async {
            RemoteVideoViewFactory.attachTrack(identity: participant.identity, track: videoTrack)
        }
        eventSink?(["event": "video_enabled", "identity": participant.identity])
    }

    public func remoteParticipant(_ participant: RemoteParticipant, unsubscribedFrom videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication) {
        DispatchQueue.main.async {
            RemoteVideoViewFactory.detachTrack(identity: participant.identity)
        }
        eventSink?(["event": "video_disabled", "identity": participant.identity])
    }
}

extension TwillioIosPlugin: CameraSourceDelegate {}
class LocalVideoViewFactory: NSObject, FlutterPlatformViewFactory {
    static var currentView: LocalVideoView?

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let view = LocalVideoView()
        LocalVideoViewFactory.currentView = view
        return view
    }
}

class LocalVideoView: NSObject, FlutterPlatformView {
    let videoView = VideoView()

    func view() -> UIView {
        videoView.contentMode = .scaleAspectFill
        return videoView
    }
}




// import Flutter
// import UIKit
//
// public class TwillioAndroidPlugin: NSObject, FlutterPlugin {
//   public static func register(with registrar: FlutterPluginRegistrar) {
//     let channel = FlutterMethodChannel(name: "twillio_android", binaryMessenger: registrar.messenger())
//     let instance = TwillioAndroidPlugin()
//     registrar.addMethodCallDelegate(instance, channel: channel)
//   }
//
//   public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//     switch call.method {
//     case "getPlatformVersion":
//       result("iOS " + UIDevice.current.systemVersion)
//     default:
//       result(FlutterMethodNotImplemented)
//     }
//   }
// }
