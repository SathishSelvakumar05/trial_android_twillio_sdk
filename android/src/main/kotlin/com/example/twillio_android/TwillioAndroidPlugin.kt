package com.example.twillio_android

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.NonNull
import com.twilio.video.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import tvi.webrtc.Camera2Enumerator




class TwillioAndroidPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        private const val EVENT_CHANNEL = "twilio_video_events"
        private const val CHANNEL = "twilio_video"
    }

    // Flutter bindings
    private lateinit var applicationContext: Context
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    // Twilio objects
    private var room: Room? = null
    private var localVideoTrack: LocalVideoTrack? = null
    private var localAudioTrack: LocalAudioTrack? = null
    private var cameraCapturer: Camera2Capturer? = null
    private lateinit var cameraEnumerator: Camera2Enumerator
    private var currentCameraId: String? = null

    // Lifecycle - attach to engine
    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext

        // Event Channel
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Method Channel
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler(this)

        // Register platform view factories
        // Use binding.platformViewRegistry for plugin registration
        binding.platformViewRegistry.registerViewFactory("LocalVideoView", LocalVideoViewFactory())
        binding.platformViewRegistry.registerViewFactory("RemoteVideoView", RemoteVideoViewFactory())
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        // Clean up
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null

        // Release Twilio resources if any
        room?.disconnect()
        room = null

        localVideoTrack?.release()
        localVideoTrack = null
        localAudioTrack?.release()
        localAudioTrack = null

        cameraCapturer?.stopCapture()
        cameraCapturer = null

        LocalVideoViewFactory.currentView = null
        LocalVideoViewFactory.pendingTrack = null
        RemoteVideoViewFactory.clearAll()
    }

    // Handle incoming method calls from Dart
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

            "reattachLocalVideoTrack" -> {
                localVideoTrack?.let { LocalVideoViewFactory.currentView?.attachTrack(it) }
                result.success(null)
            }

            "pauseLocalVideoTrack" -> {
                localVideoTrack?.let { LocalVideoViewFactory.currentView?.detachTrack(it) }
                result.success(null)
            }

            "switchCamera" -> {
                if (!::cameraEnumerator.isInitialized || cameraCapturer == null) {
                    result.error("NO_CAPTURER", "CameraCapturer is null", null)
                    return
                }

                val newCameraId = cameraEnumerator.deviceNames.firstOrNull { it != currentCameraId }
                if (newCameraId == null) {
                    result.error("NO_CAMERA", "No other camera found", null)
                    return
                }


                cameraCapturer?.switchCamera(newCameraId)
                Log.d("TwilioPlugin", "Camera switched")


                currentCameraId = newCameraId

                localVideoTrack?.let { track ->
                    LocalVideoViewFactory.currentView?.attachTrack(track)
                }
                result.success(null)
            }

            "muteAudio" -> {
                localAudioTrack?.enable(false)
                result.success(null)
            }

            "unmuteAudio" -> {
                localAudioTrack?.enable(true)
                result.success(null)
            }

            "disableVideo" -> {
                localVideoTrack?.let { track ->
                    LocalVideoViewFactory.currentView?.detachTrack(track)
                    track.release()
                    localVideoTrack = null
                }
                result.success(null)
            }

            "enableVideo" -> {
                if (!::cameraEnumerator.isInitialized || cameraCapturer == null) {
                    result.error("NO_CAPTURER", "CameraCapturer is null", null)
                    return
                }

                localVideoTrack = LocalVideoTrack.create(applicationContext, true, cameraCapturer!!)
                LocalVideoViewFactory.currentView?.attachTrack(localVideoTrack!!)

                room?.localParticipant?.let { participant ->
                    participant.publishTrack(localVideoTrack!!)
                }

                result.success(null)
            }

            "disconnect" -> {
                room?.disconnect()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // Connect to Twilio room helper
    private fun connectToRoom(token: String, roomName: String) {
        Handler(Looper.getMainLooper()).post {
            cameraEnumerator = Camera2Enumerator(applicationContext)
            currentCameraId = cameraEnumerator.deviceNames.firstOrNull { cameraEnumerator.isFrontFacing(it) }
                ?: cameraEnumerator.deviceNames.firstOrNull()

            if (currentCameraId == null) {
                Log.e("Twilio", "No camera found!")
                return@post
            }

            cameraCapturer = Camera2Capturer(applicationContext, currentCameraId!!, object : Camera2Capturer.Listener {
                override fun onFirstFrameAvailable() {
                    Log.i("TwilioCamera", "First frame received!")
                }
                override fun onCameraSwitched(newCameraId: String) {
                    Log.i("TwilioCamera", "Camera switched to $newCameraId")
                }
                override fun onError(error: Camera2Capturer.Exception) {
                    Log.e("Twilio", "Camera error: ${error.message}")
                }
            })

            localAudioTrack = LocalAudioTrack.create(applicationContext, true)
            localVideoTrack = LocalVideoTrack.create(applicationContext, true, cameraCapturer!!)

            LocalVideoViewFactory.currentView?.attachTrack(localVideoTrack!!)
                ?: run { LocalVideoViewFactory.pendingTrack = localVideoTrack }

            val connectOptions = ConnectOptions.Builder(token)
                .roomName(roomName)
                .audioTracks(listOfNotNull(localAudioTrack))
                .videoTracks(listOfNotNull(localVideoTrack))
                .build()

            room = Video.connect(applicationContext, connectOptions, roomListener)
        }
    }


    // -------------------- ROOM LISTENER --------------------
    private val roomListener = object : Room.Listener {
        override fun onConnected(room: Room) {
            room.localParticipant?.setListener(localParticipantListener)
            Log.i("Twilio", "Connected to room: ${room.name}")

            room.remoteParticipants.forEach { participant ->
                participant.setListener(remoteParticipantListener)
                eventSink?.success(mapOf("event" to "participant_connected", "identity" to participant.identity))
            }
        }

        override fun onConnectFailure(room: Room, e: TwilioException) {
            Log.e("Twilio", "Connection failed: ${e.message}")
            eventSink?.success(mapOf("event" to "connection_failed", "error" to e.message))
        }

        override fun onDisconnected(room: Room, e: TwilioException?) {
            Log.i("Twilio", "Disconnected from room")

            room.remoteParticipants.forEach { it.setListener(null) }

            localVideoTrack?.let { track ->
                LocalVideoViewFactory.currentView?.detachTrack(track)
                track.release()
                localVideoTrack = null
            }

            localAudioTrack?.release()
            localAudioTrack = null

            cameraCapturer?.stopCapture()
            cameraCapturer = null

            LocalVideoViewFactory.currentView = null
            LocalVideoViewFactory.pendingTrack = null

            RemoteVideoViewFactory.clearAll()

            this@TwillioAndroidPlugin.room = null

            eventSink?.success(mapOf("event" to "room_disconnected", "room" to room.name))
        }

        override fun onParticipantConnected(room: Room, participant: RemoteParticipant) {
            participant.setListener(remoteParticipantListener)
            eventSink?.success(mapOf("event" to "participant_connected", "identity" to participant.identity))
        }

        override fun onParticipantDisconnected(room: Room, participant: RemoteParticipant) {
            eventSink?.success(mapOf("event" to "participant_disconnected", "identity" to participant.identity))
        }

        override fun onRecordingStarted(room: Room) {
            Log.i("Twilio", "Recording started")
            eventSink?.success(mapOf("event" to "recording_started", "room" to room.name))
        }

        override fun onRecordingStopped(room: Room) {
            Log.i("Twilio", "Recording stopped")
            eventSink?.success(mapOf("event" to "recording_stopped", "room" to room.name))
        }

        override fun onReconnecting(room: Room, e: TwilioException) {
            Log.w("Twilio", "Reconnecting due to network issue: ${e.message}")
            eventSink?.success(mapOf("event" to "reconnecting", "error" to e.message))
        }

        override fun onReconnected(room: Room) {
            Log.i("Twilio", "Reconnected successfully")
            eventSink?.success(mapOf("event" to "reconnected", "room" to room.name))
        }
    }

    // -------------------- REMOTE PARTICIPANT LISTENER --------------------
    private val remoteParticipantListener = object : RemoteParticipant.Listener {
        override fun onAudioTrackPublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {
            eventSink?.success(mapOf("event" to "audio_published", "identity" to p.identity))
        }

        override fun onAudioTrackUnpublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {
            eventSink?.success(mapOf("event" to "audio_unpublished", "identity" to p.identity))
        }

        override fun onVideoTrackPublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {
            Log.i("Twilio", "Remote video published: ${p.identity}")
        }

        override fun onVideoTrackUnpublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {
            Log.i("Twilio", "Remote video unpublished: ${p.identity}")
            eventSink?.success(mapOf("event" to "video_unpublished", "identity" to p.identity))
        }

        override fun onDataTrackPublished(p: RemoteParticipant, pub: RemoteDataTrackPublication) {
            Log.i("Twilio", "DataTrack published by ${p.identity}")
        }

        override fun onDataTrackUnpublished(p: RemoteParticipant, pub: RemoteDataTrackPublication) {
            Log.i("Twilio", "DataTrack unpublished by ${p.identity}")
        }

        override fun onAudioTrackSubscribed(
            p: RemoteParticipant,
            pub: RemoteAudioTrackPublication,
            track: RemoteAudioTrack
        ) {}

        override fun onAudioTrackUnsubscribed(
            p: RemoteParticipant,
            pub: RemoteAudioTrackPublication,
            track: RemoteAudioTrack
        ) {}

        override fun onVideoTrackSubscribed(
            p: RemoteParticipant,
            pub: RemoteVideoTrackPublication,
            track: RemoteVideoTrack
        ) {
            Log.i("Twilio", "Remote video subscribed: ${p.identity}")
            Handler(Looper.getMainLooper()).post {
                RemoteVideoViewFactory.attachTrack(p.identity, track)
            }
            eventSink?.success(mapOf("event" to "video_enabled", "identity" to p.identity))
        }

        override fun onVideoTrackUnsubscribed(
            p: RemoteParticipant,
            pub: RemoteVideoTrackPublication,
            track: RemoteVideoTrack
        ) {
            Log.i("Twilio", "Remote video unsubscribed: ${p.identity}")
            Handler(Looper.getMainLooper()).post {
                RemoteVideoViewFactory.detachTrack(p.identity, track)
            }
            eventSink?.success(mapOf("event" to "video_disabled", "identity" to p.identity))
        }

        override fun onDataTrackSubscribed(
            p: RemoteParticipant,
            pub: RemoteDataTrackPublication,
            track: RemoteDataTrack
        ) {}

        override fun onDataTrackUnsubscribed(
            p: RemoteParticipant,
            pub: RemoteDataTrackPublication,
            track: RemoteDataTrack
        ) {}

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

        override fun onAudioTrackSubscriptionFailed(
            p: RemoteParticipant,
            pub: RemoteAudioTrackPublication,
            e: TwilioException
        ) {}

        override fun onVideoTrackSubscriptionFailed(
            p: RemoteParticipant,
            pub: RemoteVideoTrackPublication,
            e: TwilioException
        ) {}

        override fun onDataTrackSubscriptionFailed(
            p: RemoteParticipant,
            pub: RemoteDataTrackPublication,
            e: TwilioException
        ) {}
    }

    // -------------------- LOCAL PARTICIPANT LISTENER --------------------
    private val localParticipantListener = object : LocalParticipant.Listener {
        override fun onAudioTrackPublished(
            localParticipant: LocalParticipant,
            localAudioTrackPublication: LocalAudioTrackPublication
        ) {
            eventSink?.success(mapOf("event" to "local_audio_published"))
        }

        override fun onVideoTrackPublished(
            localParticipant: LocalParticipant,
            localVideoTrackPublication: LocalVideoTrackPublication
        ) {
            eventSink?.success(mapOf("event" to "local_video_published"))
        }

        override fun onAudioTrackPublicationFailed(
            localParticipant: LocalParticipant,
            localAudioTrack: LocalAudioTrack,
            twilioException: TwilioException
        ) {
            Log.e("Twilio", "Audio track publication failed: ${twilioException.message}")
            eventSink?.success(mapOf("event" to "local_audio_failed", "error" to twilioException.message))
        }

        override fun onVideoTrackPublicationFailed(
            localParticipant: LocalParticipant,
            localVideoTrack: LocalVideoTrack,
            twilioException: TwilioException
        ) {
            Log.e("Twilio", "Video track publication failed: ${twilioException.message}")
            eventSink?.success(mapOf("event" to "local_video_failed", "error" to twilioException.message))
        }

        override fun onDataTrackPublished(
            localParticipant: LocalParticipant,
            localDataTrackPublication: LocalDataTrackPublication
        ) {
            eventSink?.success(mapOf("event" to "local_data_published"))
        }

        override fun onDataTrackPublicationFailed(
            localParticipant: LocalParticipant,
            localDataTrack: LocalDataTrack,
            twilioException: TwilioException
        ) {
            Log.e("Twilio", "Data track publication failed: ${twilioException.message}")
            eventSink?.success(mapOf("event" to "local_data_failed", "error" to twilioException.message))
        }
    }
}

// -------------------- LOCAL VIDEO VIEW --------------------
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

// -------------------- REMOTE VIDEO VIEW --------------------
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

        fun clearAll() {
            remoteViews.clear()
            pendingTracks.clear()
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
