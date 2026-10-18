import '../../core/app_export.dart';
import './widgets/chat_detail_widget.dart';
import './widgets/conversation_list_widget.dart';

class MessageModel {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String avatarUrl;
  final String semanticLabel;
  final bool isOnline;

  const MessageModel({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.avatarUrl,
    required this.semanticLabel,
    required this.isOnline,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      name: map['name'] as String,
      lastMessage: map['lastMessage'] as String,
      time: map['time'] as String,
      unreadCount: map['unreadCount'] as int,
      avatarUrl: map['avatarUrl'] as String,
      semanticLabel: map['semanticLabel'] as String,
      isOnline: map['isOnline'] as bool,
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isSent;
  final String time;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isSent,
    required this.time,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      isSent: map['isSent'] as bool,
      time: map['time'] as String,
    );
  }
}

class MessageScreen extends StatefulWidget {
  final bool embedded;
  const MessageScreen({super.key, this.embedded = false});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  // TODO: Replace with Riverpod for production
  MessageModel? _selectedConversation;

  final List<Map<String, dynamic>> _conversationMaps = [
    {
      'id': 'c1',
      'name': 'Arjun Sharma',
      'lastMessage': 'Can I change my seat to morning shift?',
      'time': '10:32 AM',
      'unreadCount': 2,
      'avatarUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_1bf8f2d50-1763295612500.png',
      'semanticLabel':
          'Young Indian man with short black hair smiling in casual shirt',
      'isOnline': true,
    },
    {
      'id': 'c2',
      'name': 'Priya Nair',
      'lastMessage': 'Thank you for approving my request!',
      'time': '09:15 AM',
      'unreadCount': 0,
      'avatarUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_14c723b92-1763293896787.png',
      'semanticLabel':
          'Young Indian woman with long dark hair in professional attire',
      'isOnline': true,
    },
    {
      'id': 'c3',
      'name': 'Rahul Verma',
      'lastMessage': 'I will pay the dues tomorrow, sir.',
      'time': 'Yesterday',
      'unreadCount': 1,
      'avatarUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_18162979e-1763294376572.png',
      'semanticLabel':
          'Indian young man with glasses and casual blue shirt smiling',
      'isOnline': false,
    },
    {
      'id': 'c4',
      'name': 'Sneha Patel',
      'lastMessage': 'Is seat 12 available for evening?',
      'time': 'Yesterday',
      'unreadCount': 0,
      'avatarUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_1befa1d42-1772702759778.png',
      'semanticLabel': 'Young Indian woman with bun hairstyle in orange kurta',
      'isOnline': false,
    },
    {
      'id': 'c5',
      'name': 'Karan Malhotra',
      'lastMessage': 'My subscription expires next week.',
      'time': 'Mon',
      'unreadCount': 0,
      'avatarUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_17876141d-1763295390337.png',
      'semanticLabel':
          'Indian young man in navy blue polo shirt with short hair',
      'isOnline': false,
    },
    {
      'id': 'c6',
      'name': 'Riya Desai',
      'lastMessage': 'Please send my payment receipt.',
      'time': 'Sun',
      'unreadCount': 3,
      'avatarUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_199c3ae7b-1772442873446.png',
      'semanticLabel':
          'Young Indian woman with straight black hair in white top smiling',
      'isOnline': true,
    },
  ];

  late List<MessageModel> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = _conversationMaps.map(MessageModel.fromMap).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    if (isTablet) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Row(
          children: [
            SizedBox(
              width: 320,
              child: ConversationListWidget(
                conversations: _conversations,
                selectedId: _selectedConversation?.id,
                onSelect: (m) => setState(() => _selectedConversation = m),
              ),
            ),
            Container(width: 1, color: theme.colorScheme.outline),
            Expanded(
              child: _selectedConversation != null
                  ? ChatDetailWidget(
                      conversation: _selectedConversation!,
                      onBack: () =>
                          setState(() => _selectedConversation = null),
                    )
                  : _buildEmptyChat(theme),
            ),
          ],
        ),
      );
    }

    // Phone: show list or detail
    if (_selectedConversation != null) {
      return ChatDetailWidget(
        conversation: _selectedConversation!,
        onBack: () => setState(() => _selectedConversation = null),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Messages',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onSurface,
              size: 22,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ConversationListWidget(
          conversations: _conversations,
          selectedId: _selectedConversation?.id,
          onSelect: (m) => setState(() => _selectedConversation = m),
        ),
      ),
    );
  }

  Widget _buildEmptyChat(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a conversation',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a student to start messaging',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
