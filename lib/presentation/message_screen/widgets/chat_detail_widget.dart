import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../message_screen.dart';
import '../../../widgets/custom_image_widget.dart';

class ChatDetailWidget extends StatefulWidget {
  final MessageModel conversation;
  final VoidCallback onBack;

  const ChatDetailWidget({
    super.key,
    required this.conversation,
    required this.onBack,
  });

  @override
  State<ChatDetailWidget> createState() => _ChatDetailWidgetState();
}

class _ChatDetailWidgetState extends State<ChatDetailWidget> {
  // TODO: Replace with Riverpod for production
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _canSend = false;

  final List<Map<String, dynamic>> _initialMsgMaps = [
    {
      'id': 'm1',
      'text': 'Hello sir, I wanted to ask about changing my seat.',
      'isSent': false,
      'time': '10:20 AM',
    },
    {
      'id': 'm2',
      'text': 'Sure, which seat would you prefer?',
      'isSent': true,
      'time': '10:22 AM',
    },
    {
      'id': 'm3',
      'text': 'I would like Seat 05 in the morning shift if possible.',
      'isSent': false,
      'time': '10:24 AM',
    },
    {
      'id': 'm4',
      'text': 'Let me check availability for you.',
      'isSent': true,
      'time': '10:25 AM',
    },
    {
      'id': 'm5',
      'text':
          'Seat 05 is available from tomorrow morning. I\'ll assign it to you.',
      'isSent': true,
      'time': '10:27 AM',
    },
    {
      'id': 'm6',
      'text': 'Can I change my seat to morning shift?',
      'isSent': false,
      'time': '10:32 AM',
    },
  ];

  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = _initialMsgMaps.map(ChatMessage.fromMap).toList();
    _msgCtrl.addListener(() {
      setState(() => _canSend = _msgCtrl.text.trim().isNotEmpty);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'm${_messages.length + 1}',
          text: text,
          isSent: true,
          time: timeStr,
        ),
      );
    });
    _msgCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.colorScheme.onSurface,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CustomImageWidget(
                    imageUrl: widget.conversation.avatarUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    semanticLabel: widget.conversation.semanticLabel,
                  ),
                ),
                if (widget.conversation.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  widget.conversation.isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: widget.conversation.isOnline
                        ? const Color(0xFF10B981)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.call_outlined,
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.more_vert_rounded,
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.outline,
                      thickness: 0.5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Today',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.outline,
                      thickness: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final msg = _messages[i];
                  return _ChatBubble(message: msg);
                },
              ),
            ),
            // Input bar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outline, width: 0.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: theme.colorScheme.outline,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _msgCtrl,
                              maxLines: null,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.attach_file_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _canSend
                          ? const Color(0xFF4F46E5)
                          : theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: InkWell(
                      onTap: _canSend ? _sendMessage : null,
                      borderRadius: BorderRadius.circular(22),
                      child: Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: _canSend
                            ? Colors.white
                            : theme.colorScheme.onSurfaceVariant,
                      ),
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
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSent = message.isSent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isSent
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent) const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: isSent
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isSent
                        ? const Color(0xFF4F46E5)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isSent ? 16 : 4),
                      bottomRight: Radius.circular(isSent ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isSent
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.time,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isSent) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all_rounded,
                        size: 12,
                        color: const Color(0xFF4F46E5),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isSent) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
