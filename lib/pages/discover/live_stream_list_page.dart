import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/api/api_client.dart';
import '../../services/websocket_service.dart';
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
  int _currentTab = 1; // 1=直播中, 0=即将开始, 2=已结束

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tabs = [1, 0, 2];
        setState(() => _currentTab = tabs[_tabController.index]);
      }
    });
    _loadStreams();
    // 监听 WebSocket 直播更新事件
    WebSocketService.instance.on('live_stream_update', _onLiveStreamUpdate);
  }

  @override
  void dispose() {
    WebSocketService.instance.off('live_stream_update', _onLiveStreamUpdate);
    _tabController.dispose();
    super.dispose();
  }

  void _onLiveStreamUpdate(Map<String, dynamic> message) {
    _loadStreams();
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
        // 自动选择默认 tab：有直播中选直播中，否则默认即将开始
        if (_liveCount > 0) {
          _tabController.index = 0;
          _currentTab = 1;
        } else {
          _tabController.index = 1;
          _currentTab = 0;
        }
      }
    } catch (e) {
      debugPrint('[LiveStream] load error: $e');
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredStreams {
    return _streams.where((s) => s['status'] == _currentTab).toList();
  }

  int get _liveCount => _streams.where((s) => s['status'] == 1).length;
  int get _upcomingCount => _streams.where((s) => s['status'] == 0).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            const Text('体育直播'),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: isDark ? AppColors.darkText : AppColors.lightText,
          unselectedLabelColor: AppColors.systemGray,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
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
    String message;
    switch (_currentTab) {
      case 1:
        message = '暂无直播，稍后再来看看吧';
        break;
      case 0:
        message = '暂无即将开始的比赛';
        break;
      default:
        message = '暂无已结束的比赛';
    }
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(CupertinoIcons.tv, size: 56, color: AppColors.systemGray3),
              const SizedBox(height: 16),
              Text(message, style: TextStyle(fontSize: 15, color: AppColors.systemGray)),
            ],
          ),
        ),
      ],
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
    final matchTime = stream['match_time'] as String?;
    final isLive = status == 1;
    final broadcaster = stream['broadcaster'] as Map<String, dynamic>?;
    final broadcasterAvatar = broadcaster?['avatar'] as String?;
    final broadcasterName = broadcaster?['nickname'] ?? '主播';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => LiveStreamPlayerPage(stream: stream)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2332) : const Color(0xFFFCFCFD),
          borderRadius: BorderRadius.circular(12),
          border: isLive
              ? Border.all(color: AppColors.error.withAlpha(isDark ? 50 : 30), width: 1)
              : Border.all(color: isDark ? AppColors.darkDivider : const Color(0xFFEEEEEE), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 6),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左：主播头像（仅在有主播时显示）
            if (broadcaster != null) ...[
              Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isLive
                          ? const LinearGradient(colors: [Color(0xFFAA5CFC), Color(0xFF7C5CFC)])
                          : null,
                      border: !isLive ? Border.all(color: AppColors.systemGray3, width: 1.5) : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkCard : Colors.white,
                      ),
                      padding: const EdgeInsets.all(1.5),
                      child: ClipOval(
                        child: broadcasterAvatar != null && broadcasterAvatar.isNotEmpty
                            ? Image.network(
                                broadcasterAvatar.startsWith('http') ? broadcasterAvatar : '${ApiConfig.baseUrl}$broadcasterAvatar',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(isDark),
                              )
                            : _buildAvatarPlaceholder(isDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    broadcasterName.length > 4 ? broadcasterName.substring(0, 4) : broadcasterName,
                    style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextTertiary : AppColors.systemGray),
                  ),
                ],
              ),
              const SizedBox(width: 14),
            ],
            // 中：赛事信息（联赛 + 两队比分）
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 联赛
                  Row(
                    children: [
                      if (stream['league_logo'] != null && (stream['league_logo'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Image.network(
                            (stream['league_logo'] as String).startsWith('http') ? stream['league_logo'] : '${ApiConfig.baseUrl}${stream['league_logo']}',
                            width: 14, height: 14, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        ),
                      Text(league, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.systemGray)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 主队行
                  Row(
                    children: [
                      _buildSmallTeamLogo(homeLogo, homeTeam, isDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(homeTeam, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkText : AppColors.lightText), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (homeScore != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('$homeScore', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isLive ? AppColors.error : (isDark ? AppColors.darkText : AppColors.lightText))),
                        ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    height: 0.5,
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  ),
                  // 客队行
                  Row(
                    children: [
                      _buildSmallTeamLogo(awayLogo, awayTeam, isDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(awayTeam, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkText : AppColors.lightText), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (awayScore != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('$awayScore', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isLive ? AppColors.error : (isDark ? AppColors.darkText : AppColors.lightText))),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // 右侧分隔线
            Container(
              width: 0.5,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
            // 右：时间 + 状态
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (matchTime != null)
                  Text(_formatTime(matchTime), style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.systemGray2)),
                const SizedBox(height: 8),
                _buildStatusTag(status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkCardElevated : AppColors.lightInputBg,
      child: Icon(CupertinoIcons.person_fill, size: 22, color: isDark ? AppColors.darkTextTertiary : AppColors.systemGray3),
    );
  }

  Widget _buildSmallTeamLogo(String? logoUrl, String teamName, bool isDark) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final url = logoUrl.startsWith('http') ? logoUrl : '${ApiConfig.baseUrl}$logoUrl';
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.network(url, width: 18, height: 18, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildSmallTeamPlaceholder(teamName, isDark)),
      );
    }
    return _buildSmallTeamPlaceholder(teamName, isDark);
  }

  Widget _buildSmallTeamPlaceholder(String teamName, bool isDark) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightInputBg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Text(teamName.isNotEmpty ? teamName[0] : '?', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
      ),
    );
  }

  Widget _buildStatusTag(int status) {
    switch (status) {
      case 1:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('▐▌', style: TextStyle(fontSize: 8, color: Colors.white)),
              SizedBox(width: 3),
              Text('直播中', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      case 0:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('即将开始', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500)),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.systemGray.withAlpha(20),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('已结束', style: TextStyle(color: AppColors.systemGray, fontSize: 11, fontWeight: FontWeight.w500)),
        );
    }
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
