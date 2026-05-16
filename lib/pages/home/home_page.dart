import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/conversation_provider.dart';
import '../../services/websocket_service.dart';
import '../chat/conversation_list_page.dart';
import '../contacts/contacts_page.dart';
import '../discover/discover_page.dart';
import '../profile/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = const [
    ConversationListPage(),
    ContactsPage(),
    DiscoverPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保 WebSocket 连接
      WebSocketService.instance.connect();
      // 加载会话列表
      context.read<ConversationProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final convProvider = context.watch<ConversationProvider>();
    final unread = convProvider.totalUnread;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              activeIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: '消息',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: '通讯录',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: '发现',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
