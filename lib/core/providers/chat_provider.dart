import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
class ChatMessage {
  final int id;
  final String sender; // 'user', 'bot', 'admin', 'system'
  final String message;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      sender: json['sender'] ?? 'bot',
      message: json['message'] ?? '',
      createdAt: DateTime.now(),
    );
  }
}

class ChatProvider with ChangeNotifier {
  // CENTRAL HUB URL (Cloudflare Worker)
  final String _hubUrl = 'https://ai-project-1.jemytrade72345.workers.dev/web-chat';
  final String _wpUrl = 'https://www.jemypedia.com';
  
  List<ChatMessage> _messages = [
    ChatMessage(
      id: -1,
      sender: 'bot',
      message: 'مرحباً بك في دعم Jemypedia! كيف يمكنني مساعدتك؟',
      createdAt: DateTime.now(),
    )
  ];
  String? _sessionId;
  String? _secretKey;
  bool _isLoading = false;
  bool _isHumanSupport = false;
  Timer? _pollingTimer;
  int _lastMsgId = 0;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isHumanSupport => _isHumanSupport;
  String? get sessionId => _sessionId;

  void setSecretKey(String key) {
    _secretKey = key;
  }

  Future<void> initSession(String name, String email) async {
    if (_sessionId != null) return;
    
    final prefs = await SharedPreferences.getInstance();
    String? savedSessionId = prefs.getString('omni_session_id');
    
    if (savedSessionId == null) {
      savedSessionId = 'sess_flutter_${const Uuid().v4().replaceAll('-', '').substring(0, 10)}';
      await prefs.setString('omni_session_id', savedSessionId);
    }
    
    _sessionId = savedSessionId;
    startPolling();
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      fetchUpdates();
    });
  }

  Future<void> fetchUpdates() async {
    // Admin replies are routed through the Cloudflare Worker (Omni-Agent V2).
    // The WP polling endpoint is not needed in the new architecture and
    // causes CORS errors on Flutter Web, so it is intentionally disabled.
    return;
  }

  Future<void> sendMessage(String text) async {
    if (_sessionId == null || text.trim().isEmpty) return;

    // Optimistic Update
    final tempMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      sender: 'user',
      message: text,
      createdAt: DateTime.now(),
    );
    _messages.add(tempMsg);
    notifyListeners();

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(_hubUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "wp_url": _wpUrl,
          "secret": _secretKey ?? "3kr4EuvwvOVfrDVHuEuKW9gO",
          "site_label": "Jemypedia App",
          "source": "Flutter Desktop/Web",
          "message": text,
          "session_id": _sessionId,
          "status": "bot"
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiReply = data['reply'];
        
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          sender: 'bot',
          message: aiReply,
          createdAt: DateTime.now(),
        ));
      } else {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          sender: 'system',
          message: 'Error ${response.statusCode}: ${response.body}',
          createdAt: DateTime.now(),
        ));
      }
    } catch (e) {
      print('Error sending message to Hub: $e');
      _messages.add(ChatMessage(
        id: 0,
        sender: 'system',
        message: 'Connection error. Please check your internet.',
        createdAt: DateTime.now(),
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
