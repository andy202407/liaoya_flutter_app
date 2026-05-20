import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/api/api_client.dart';
import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
import 'live_stream_player_page.dart';

class LiveStreamListPage extends StatefulWidget {
  const LiveStreamListPage({super.key});

  @override
  State<LiveStreamListPage> createState() => _LiveStreamListPageState();
}

class _LiveStreamListPageState extends State<LiveStreamListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _streams = [];
  bool _isLoading = true;
  int _currentTab = -1; // -1=全部, 0=即将开始, 1=直播中, 2=已结束

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tabs = [-1, 1, 0, 2];
        setState(() => _currentTab = tabs[_tabController.index]);
      }
    });
    _loadStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStreams() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.dio.get('/user/live-streams');
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        setState(() {
          _streams = data.map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (e) {
      debugPrint('[LiveStream] load error: $e');
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredStreams {
    if (_currentTab == -1) return _streams;
    return _streams.where((s) => s['status'] == _currentTab).toList();
  }

  int get _liveCount => _streams.where((s) => s['status'] == 1).length;
  int get _upcomingCount => _streams.where((s) => s['status'] == 0).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('体育直播'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: isDark ? AppColors.darkText : AppColors.lightText,
          unselectedLabelColor: AppColors.systemGray,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            const Tab(text: '全部'),
            Tab(child: _buildTabWithBadge('直播中', _liveCount, AppColors.error)),
            Tab(child: _buildTabWithBadge('即将开始', _upcomingCount, AppColors.warning)),
            const Tab(text: '已结束'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
              onRefresh: _loadStreams,
              child: _filteredStreams.isEmpty
                  ? _buildEmpty(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredStreams.length,
                      itemBuilder: (context, index) {
                        return _buildStreamCard(_filteredStreams[index], isDark);
                      },
                    ),
            ),
    );
  }

  Widget _buildTabWithBadge(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.tv, size: 56, color: AppColors.systemGray3),
          const SizedBox(height: 16),
          Text('暂无直播', style: TextStyle(fontSize: 15, color: AppColors.systemGray)),
        ],
      ),
    );
  }

  Widget _buildStreamCard(Map<String, dynamic> stream, bool isDark) {
    final status = stream['status'] as int? ?? 0;
    final league = stream['league'] ?? '';
    final homeTeam = stream['home_team'] ?? '主队';
    final awayTeam = stream['away_team'] ?? '客队';
    final homeScore = stream['home_score'];
    final awayScore = stream['away_score'];
    final homeLogo = stream['home_logo'] as String?;
    final awayLogo = stream['away_logo'] as String?;
    final coverImage = stream['cover_image'] as String?;
    final viewCount = stream['view_count'] as int? ?? 0;
    final matchTime = stream['match_time'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => LiveStreamPlayerPage(stream: stream)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 封面区域
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 封面图
                  if (coverImage != null && coverImage.isNotEmpty)
                    Image.network(
                      coverImage.startsWith('http') ? coverImage : '${ApiConfig.baseUrl}$coverImage',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultCover(isDark),
                    )
                  else
                    _buildDefaultCover(isDark),
                  // 渐变遮罩
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withAlpha(120)],
                      ),
                    ),
                  ),
                  // 状态标签
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _buildStatusBadge(status),
                  ),
                  // 观看人数
                  if (viewCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.eye, size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text('$viewCount', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 对阵信息
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // 联赛 + 时间
                  if (league.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Text(
                            league,
                            style: TextStyle(fontSize: 12, color: AppColors.systemGray, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          if (matchTime != null)
                            Text(
                              _formatTime(matchTime),
                              style: TextStyle(fontSize: 11, color: AppColors.systemGray2),
                            ),
                        ],
                      ),
                    ),
                  // 对阵
                  Row(
                    children: [
                      // 主队
                      Expanded(
                        child: Row(
                          children: [
                            if (homeLogo != null && homeLogo.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(homeLogo, width: 24, height: 24, fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const SizedBox(width: 24, height: 24)),
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                homeTeam,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 比分
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBg : AppColors.lightBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: homeScore != null && awayScore != null
                            ? Text(
                                '$homeScore - $awayScore',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: status == 1 ? AppColors.error : (isDark ? AppColors.darkText : AppColors.lightText),
                                ),
                              )
                            : Text(
                                'VS',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.systemGray,
                                ),
                              ),
                      ),
                      // 客队
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                awayTeam,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (awayLogo != null && awayLogo.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(awayLogo, width: 24, height: 24, fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const SizedBox(width: 24, height: 24)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCover(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkCardElevated : AppColors.lightInputBg,
      child: Center(
        child: Icon(CupertinoIcons.tv, size: 40, color: AppColors.systemGray3),
      ),
    );
  }

  Widget _buildStatusBadge(int status) {
    Color bgColor;
    String text;
    switch (status) {
      case 1:
        bgColor = AppColors.error;
        text = '● 直播中';
        break;
      case 0:
        bgColor = AppColors.warning;
        text = '即将开始';
        break;
      default:
        bgColor = AppColors.systemGray;
        text = '已结束';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final time = DateTime.parse(timeStr);
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timeStr;
    }
  }
}
