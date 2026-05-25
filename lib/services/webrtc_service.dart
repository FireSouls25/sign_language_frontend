import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signal_websocket_service.dart';

enum CallState { disconnected, connecting, connected }

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final _callStateController = StreamController<CallState>.broadcast();
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();

  Stream<CallState> get callStateStream => _callStateController.stream;
  Stream<MediaStream?> get remoteStreamStream => _remoteStreamController.stream;

  CallState _state = CallState.disconnected;
  CallState get state => _state;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  SignalWebSocketService? _signalWs;
  String? _otherUserId;

  static const _iceServers = <Map<String, dynamic>>[
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  void initialize({
    required SignalWebSocketService signalWs,
    required String otherUserId,
  }) {
    _signalWs = signalWs;
    _otherUserId = otherUserId;
  }

  Future<bool> startCall() async {
    if (_signalWs == null || _otherUserId == null) return false;

    _updateState(CallState.connecting);

    try {
      final constraints = <String, dynamic>{
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      _peerConnection = await createPeerConnection({
        'iceServers': _iceServers,
      });

      _peerConnection!.onIceCandidate = (candidate) {
        if (_signalWs != null && _otherUserId != null) {
          _signalWs!.sendIceCandidate(_otherUserId!, {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid ?? '',
            'sdpMLineIndex': candidate.sdpMLineIndex ?? 0,
          });
        }
      };

      _peerConnection!.onIceConnectionState = (state) {
        debugPrint('[WebRTC] ICE state: $state');
      };

      _peerConnection!.onTrack = (event) {
        if (event.track.kind == 'video') {
          _remoteStream = event.streams[0];
          _remoteStreamController.add(_remoteStream);
        }
      };

      _peerConnection!.onAddStream = (stream) {
        _remoteStream = stream;
        _remoteStreamController.add(stream);
      };

      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      if (_signalWs != null && _otherUserId != null) {
        _signalWs!.sendOffer(
          _otherUserId!,
          jsonEncode(offer.toMap()),
        );
      }

      _updateState(CallState.connected);
      return true;
    } catch (e) {
      debugPrint('[WebRTC] startCall error: $e');
      _updateState(CallState.disconnected);
      return false;
    }
  }

  Future<void> handleOffer(Map<String, dynamic> data) async {
    _updateState(CallState.connecting);

    try {
      final constraints = <String, dynamic>{
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      _peerConnection = await createPeerConnection({
        'iceServers': _iceServers,
      });

      _peerConnection!.onIceCandidate = (candidate) {
        if (_signalWs != null && _otherUserId != null) {
          _signalWs!.sendIceCandidate(_otherUserId!, {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid ?? '',
            'sdpMLineIndex': candidate.sdpMLineIndex ?? 0,
          });
        }
      };

      _peerConnection!.onIceConnectionState = (state) {
        debugPrint('[WebRTC] ICE state: $state');
      };

      _peerConnection!.onTrack = (event) {
        if (event.track.kind == 'video') {
          _remoteStream = event.streams[0];
          _remoteStreamController.add(_remoteStream);
        }
      };

      _peerConnection!.onAddStream = (stream) {
        _remoteStream = stream;
        _remoteStreamController.add(stream);
      };

      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      final sdp = data['sdp'] as String;
      final type = data['type'] as String? ?? 'offer';
      final desc = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(desc);

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      if (_signalWs != null && _otherUserId != null) {
        _signalWs!.sendAnswer(
          _otherUserId!,
          jsonEncode(answer.toMap()),
        );
      }

      _updateState(CallState.connected);
    } catch (e) {
      debugPrint('[WebRTC] handleOffer error: $e');
      _updateState(CallState.disconnected);
    }
  }

  Future<void> handleAnswer(Map<String, dynamic> data) async {
    try {
      final sdp = data['sdp'] as String;
      final type = data['type'] as String? ?? 'answer';
      final desc = RTCSessionDescription(sdp, type);
      await _peerConnection?.setRemoteDescription(desc);
    } catch (e) {
      debugPrint('[WebRTC] handleAnswer error: $e');
    }
  }

  Future<void> handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final candidate = data['candidate'] as Map<String, dynamic>;
      final rtcCandidate = RTCIceCandidate(
        candidate['candidate'] as String,
        candidate['sdpMid'] as String,
        candidate['sdpMLineIndex'] as int,
      );
      await _peerConnection?.addCandidate(rtcCandidate);
    } catch (e) {
      debugPrint('[WebRTC] handleIceCandidate error: $e');
    }
  }

  Future<void> endCall() async {
    _peerConnection?.close();
    _peerConnection = null;

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      _localStream = null;
    }

    _remoteStream = null;
    _remoteStreamController.add(null);
    _updateState(CallState.disconnected);
  }

  Future<void> toggleMic() async {
    if (_localStream == null) return;
    final audioTracks = _localStream!.getAudioTracks();
    for (final track in audioTracks) {
      track.enabled = !track.enabled;
    }
  }

  Future<void> toggleCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    for (final track in videoTracks) {
      track.enabled = !track.enabled;
    }
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    await Helper.switchCamera(_localStream!.getVideoTracks().first);
  }

  void _updateState(CallState newState) {
    _state = newState;
    _callStateController.add(newState);
  }

  void dispose() {
    endCall();
    _callStateController.close();
    _remoteStreamController.close();
  }
}
