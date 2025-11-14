import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/chat_service.dart';
import '../../../models/message_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String receiverId;
  final String? roomId;

  const ChatScreen({
    super.key,
    required this.receiverId,
    this.roomId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Hôm qua ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    await _chatService.sendMessage(
      receiverId: widget.receiverId,
      text: text,
      roomId: widget.roomId,
    );

    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final receiverAsync = ref.watch(userStreamProvider(widget.receiverId));
    final messagesStream = _chatService.getMessagesStream(widget.receiverId);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: receiverAsync.when(
          data: (user) => user != null
              ? InkWell(
                  onTap: () {
                    // Could navigate to user profile
                  },
                  child: Row(
                    children: [
                      Hero(
                        tag: 'avatar_${user.id}',
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            backgroundColor: colorScheme.primaryContainer,
                            child: user.avatarUrl == null
                                ? Text(
                                    user.fullName.isNotEmpty
                                        ? user.fullName[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (user.phoneNumber != null)
                              Text(
                                user.phoneNumber!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : const Text('Chat'),
          loading: () => const Text('Chat'),
          error: (_, __) => const Text('Chat'),
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 80,
                            color: colorScheme.primary.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Chưa có tin nhắn nào',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bắt đầu cuộc trò chuyện với người này',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isMe = message.senderId == currentUser?.id;
                    final prevMessage = index < messages.length - 1
                        ? messages[messages.length - 2 - index]
                        : null;
                    final showTimestamp = prevMessage == null ||
                        message.createdAt.difference(prevMessage.createdAt).inMinutes > 5;
                    final isSameSender = prevMessage != null && 
                        prevMessage.senderId == message.senderId &&
                        message.createdAt.difference(prevMessage.createdAt).inMinutes < 5;

                    return Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (showTimestamp)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _formatMessageTime(message.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: isMe ? 50 : 0,
                            right: isMe ? 0 : 50,
                            bottom: isSameSender ? 4 : 8,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              gradient: isMe
                                  ? LinearGradient(
                                      colors: [
                                        colorScheme.primary,
                                        colorScheme.primary.withOpacity(0.9),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isMe
                                  ? null
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(isMe ? 20 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isMe 
                                      ? colorScheme.primary 
                                      : Colors.black).withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              message.text,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: isMe
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                                height: 1.5,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Input Field
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                              fontSize: 15,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 15,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(28),
                      elevation: 2,
                      shadowColor: colorScheme.primary.withOpacity(0.4),
                      child: InkWell(
                        onTap: _sendMessage,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            color: colorScheme.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

