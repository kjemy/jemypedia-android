import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chat = Provider.of<ChatProvider>(context, listen: false);
      
      if (auth.omniSecretKey != null) {
        chat.setSecretKey(auth.omniSecretKey!);
      }
      
      chat.initSession(auth.displayName ?? 'Student', auth.userEmail ?? '');
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Auto scroll on new messages
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  chat.isHumanSupport ? 'Human Support Active' : 'AI Online',
                  style: const TextStyle(fontSize: 10, color: Colors.greenAccent),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: GlassContainer(
          customBorderRadius: BorderRadius.zero,
          color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
          child: Container(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [Colors.black, const Color(0xFF1A1A1A)] 
              : [const Color(0xFFF5F5F5), Colors.white],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: chat.sessionId == null && chat.messages.length <= 1
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentNeon))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                  final msg = chat.messages[index];
                  final isUser = msg.sender == 'user';
                  final isSystem = msg.sender == 'system';
                  
                  if (isSystem) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(msg.message, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      ),
                    );
                  }

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      child: Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          GlassContainer(
                            color: isUser 
                              ? AppColors.primary.withOpacity(0.8) 
                              : (isDark ? Colors.white10 : Colors.black12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            customBorderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isUser ? 20 : 0),
                              bottomRight: Radius.circular(isUser ? 0 : 20),
                            ),
                            child: Text(
                              msg.message,
                              style: TextStyle(color: isUser ? Colors.white : textColor, fontSize: 14, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isUser ? 'You' : (msg.sender == 'admin' ? 'Support' : 'AI'),
                            style: const TextStyle(fontSize: 10, color: Colors.white24),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Input Area
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (val) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      Provider.of<ChatProvider>(context, listen: false).sendMessage(_messageController.text);
      _messageController.clear();
    }
  }
}
