import 'package:flutter/material.dart';

// 你的三个既有页面
import 'new_request_page.dart';
import 'pending_page.dart';
import 'history_page.dart';

class PartRequestTabsPage extends StatelessWidget {
  const PartRequestTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,            // 三个 Tab
      initialIndex: 0,      // 默认打开 NEW REQUEST
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFE63936),
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Part Request',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          bottom: const TabBar(
            isScrollable: false,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'NEW REQUEST'),
              Tab(text: 'PENDING'),
              Tab(text: 'HISTORY'),
            ],
          ),
        ),
        body: const TabBarView(
          // 想禁止左右滑动的话，改成：
          // physics: NeverScrollableScrollPhysics(),
          children: [
            _KeepAlive(child: NewRequestPage()),
            _KeepAlive(child: PendingPage()),
            _KeepAlive(child: HistoryPage()),
          ],
        ),
      ),
    );
  }
}

/// 让每个 Tab 切换后依然保持内容（表单输入、滚动位置等不会丢）
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
