package com.example.twillio_android

import android.content.Context
import android.util.Log
import android.widget.FrameLayout
import android.view.View
import androidx.annotation.NonNull
import com.twilio.video.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.*
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import tvi.webrtc.Camera2Enumerator

class TwillioAndroidPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private var room: Room? = null
    private var localVideoTrack: LocalVideoTrack? = null
    private var localAudioTrack: LocalAudioTrack? = null
    private var cameraCapturer: Camera2Capturer? = null
    private lateinit var cameraEnumerator: Camera2Enumerator
    private var currentCameraId: String? = null
    private lateinit var context: Context

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "twilio_video")
        eventChannel = EventChannel(binding.binaryMessenger, "twilio_video_events")

        channel.setMethodCallHandler(this)

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Register platform views
        binding.platformViewRegistry.registerViewFactory("LocalVideoView", LocalVideoViewFactory())
        binding.platformViewRegistry.registerViewFactory("RemoteVideoView", RemoteVideoViewFactory())
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connectToRoom" -> {
                val token = call.argument<String>("token")
                val roomName = call.argument<String>("roomName")
                if (token.isNullOrEmpty() || roomName.isNullOrEmpty()) {
                    result.error("ARG_NULL", "Token or RoomName is null", null)
                    return
                }
                connectToRoom(token, roomName)
                result.success("Connecting to $roomName")
            }
            "switchCamera" -> switchCamera(result)
            "muteAudio" -> { localAudioTrack?.enable(false); result.success(null) }
            "unmuteAudio" -> { localAudioTrack?.enable(true); result.success(null) }
            "disableVideo" -> { localVideoTrack?.enable(false); result.success(null) }
            "enableVideo" -> { localVideoTrack?.enable(true); result.success(null) }
            "disconnect" -> { room?.disconnect(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun connectToRoom(token: String, roomName: String) {
        cameraEnumerator = Camera2Enumerator(context)
        currentCameraId = cameraEnumerator.deviceNames.firstOrNull { cameraEnumerator.isFrontFacing(it) }
            ?: cameraEnumerator.deviceNames.firstOrNull()
        if (currentCameraId == null) {
            Log.e("Twilio", "No camera found!")
            return
        }

        cameraCapturer = Camera2Capturer(context, currentCameraId!!, object : Camera2Capturer.Listener {
            override fun onFirstFrameAvailable() {
                Log.i("TwilioCamera", "First frame received!")
            }

            override fun onCameraSwitched(newCameraId: String) {
                Log.i("TwilioCamera", "Switched: $newCameraId")
            }

            override fun onError(error: Camera2Capturer.Exception) {
                Log.e("Twilio", "Camera error: ${error.message}")
            }
        })


        localAudioTrack = LocalAudioTrack.create(context, true)
        localVideoTrack = LocalVideoTrack.create(context, true, cameraCapturer!!)
        LocalVideoViewFactory.currentView?.attachTrack(localVideoTrack!!)

        val connectOptions = ConnectOptions.Builder(token)
            .roomName(roomName)
            .audioTracks(listOfNotNull(localAudioTrack))
            .videoTracks(listOfNotNull(localVideoTrack))
            .build()

        room = Video.connect(context, connectOptions, roomListener)
    }

    private fun switchCamera(result: MethodChannel.Result) {
        if (cameraCapturer == null) {
            result.error("NO_CAPTURER", "CameraCapturer is null", null)
            return
        }
        val newCameraId = cameraEnumerator.deviceNames.firstOrNull { it != currentCameraId }
        if (newCameraId == null) {
            result.error("NO_CAMERA", "No other camera found", null)
            return
        }
        cameraCapturer?.switchCamera(newCameraId)
        currentCameraId = newCameraId
        result.success(null)
    }

    private val roomListener = object : Room.Listener {
        override fun onConnected(room: Room) {
            eventSink?.success(mapOf("event" to "connected", "room" to room.name))
            room.remoteParticipants.forEach { it.setListener(remoteParticipantListener) }
        }
        override fun onConnectFailure(room: Room, e: TwilioException) {
            eventSink?.success(mapOf("event" to "connection_failed", "error" to e.message))
        }
        override fun onDisconnected(room: Room, e: TwilioException?) {
            eventSink?.success(mapOf("event" to "disconnected", "room" to room.name))
        }
        override fun onParticipantConnected(room: Room, participant: RemoteParticipant) {
            eventSink?.success(mapOf("event" to "participant_connected", "identity" to participant.identity))
            participant.setListener(remoteParticipantListener)
        }
        override fun onParticipantDisconnected(room: Room, participant: RemoteParticipant) {
            eventSink?.success(mapOf("event" to "participant_disconnected", "identity" to participant.identity))
        }
        override fun onRecordingStarted(room: Room) {
            eventSink?.success(mapOf("event" to "recording_started", "room" to room.name))
        }
        override fun onRecordingStopped(room: Room) {
            eventSink?.success(mapOf("event" to "recording_stopped", "room" to room.name))
        }
        override fun onReconnecting(room: Room, e: TwilioException) {}
        override fun onReconnected(room: Room) {}
    }

    private val remoteParticipantListener = object : RemoteParticipant.Listener {
        override fun onVideoTrackSubscribed(p: RemoteParticipant, pub: RemoteVideoTrackPublication, track: RemoteVideoTrack) {
            RemoteVideoViewFactory.attachTrack(p.identity, track)
        }
        override fun onVideoTrackUnsubscribed(p: RemoteParticipant, pub: RemoteVideoTrackPublication, track: RemoteVideoTrack) {
            RemoteVideoViewFactory.detachTrack(p.identity, track)
        }

        override fun onAudioTrackEnabled(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {
            eventSink?.success(mapOf("event" to "audio_enabled", "identity" to p.identity))
        }

        override fun onAudioTrackDisabled(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {
            eventSink?.success(mapOf("event" to "audio_disabled", "identity" to p.identity))
        }

        override fun onVideoTrackEnabled(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {
            eventSink?.success(mapOf("event" to "video_enabled", "identity" to p.identity))
        }

        override fun onVideoTrackDisabled(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {
            eventSink?.success(mapOf("event" to "video_disabled", "identity" to p.identity))
        }

        // Required but unused methods
        override fun onAudioTrackSubscribed(p: RemoteParticipant, pub: RemoteAudioTrackPublication, t: RemoteAudioTrack) {}
        override fun onAudioTrackUnsubscribed(p: RemoteParticipant, pub: RemoteAudioTrackPublication, t: RemoteAudioTrack) {}
        override fun onDataTrackSubscribed(p: RemoteParticipant, pub: RemoteDataTrackPublication, t: RemoteDataTrack) {}
        override fun onDataTrackUnsubscribed(p: RemoteParticipant, pub: RemoteDataTrackPublication, t: RemoteDataTrack) {}
        override fun onAudioTrackPublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
        override fun onAudioTrackUnpublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
        override fun onVideoTrackPublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
        override fun onVideoTrackUnpublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
        override fun onDataTrackPublished(p: RemoteParticipant, pub: RemoteDataTrackPublication) {}
        override fun onDataTrackUnpublished(p: RemoteParticipant, pub: RemoteDataTrackPublication) {}
        override fun onAudioTrackSubscriptionFailed(p: RemoteParticipant, pub: RemoteAudioTrackPublication, e: TwilioException) {}
        override fun onVideoTrackSubscriptionFailed(p: RemoteParticipant, pub: RemoteVideoTrackPublication, e: TwilioException) {}
        override fun onDataTrackSubscriptionFailed(p: RemoteParticipant, pub: RemoteDataTrackPublication, e: TwilioException) {}
    }
}
// -------------------- LocalVideoView --------------------
class LocalVideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        var currentView: LocalVideoView? = null
        var pendingTrack: LocalVideoTrack? = null
    }

    override fun create(context: Context?, id: Int, args: Any?): PlatformView {
        val view = LocalVideoView(context ?: throw IllegalStateException("Context cannot be null"))
        currentView = view
        pendingTrack?.let {
            view.attachTrack(it)
            pendingTrack = null
        }
        return view
    }
}

class LocalVideoView(context: Context) : PlatformView {
    private val frameLayout = FrameLayout(context)
    private val videoView = VideoView(context)

    init {
        videoView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        frameLayout.addView(videoView)
    }

    fun attachTrack(track: LocalVideoTrack) = track.addSink(videoView)
    fun detachTrack(track: LocalVideoTrack) = track.removeSink(videoView)
    override fun getView(): View = frameLayout
    override fun dispose() {}
}

// -------------------- RemoteVideoView --------------------
class RemoteVideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        private val remoteViews = mutableMapOf<String, RemoteVideoView>()
        private val pendingTracks = mutableMapOf<String, RemoteVideoTrack>()

        fun attachTrack(identity: String, track: RemoteVideoTrack) {
            remoteViews[identity]?.attachTrack(track) ?: run {
                pendingTracks[identity] = track
            }
        }

        fun detachTrack(identity: String, track: RemoteVideoTrack) {
            remoteViews[identity]?.detachTrack(track)
        }

        fun detachAllForParticipant(identity: String) {
            remoteViews.remove(identity)
            pendingTracks.remove(identity)
        }
    }

    override fun create(context: Context?, id: Int, args: Any?): PlatformView {
        val identity = (args as? Map<*, *>)?.get("identity") as? String
            ?: throw IllegalArgumentException("Missing identity for RemoteVideoView")
        val view = RemoteVideoView(context ?: throw IllegalStateException("Context cannot be null"))
        remoteViews[identity] = view
        pendingTracks.remove(identity)?.let { view.attachTrack(it) }
        return view
    }
}

class RemoteVideoView(context: Context) : PlatformView {
    private val frameLayout = FrameLayout(context)
    private val videoView = VideoView(context)

    init {
        videoView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        frameLayout.addView(videoView)
    }

    fun attachTrack(track: RemoteVideoTrack) = track.addSink(videoView)
    fun detachTrack(track: RemoteVideoTrack) = track.removeSink(videoView)
    override fun getView(): View = frameLayout
    override fun dispose() {}
}
