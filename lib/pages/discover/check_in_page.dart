import 'package:flutter/material.dart';
import '../../services/api/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final _dio = ApiClient.instance.dio;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _calendar = [];
  List<Map<String, dynamic>> _ranking = [];
  int _myRank = 0;
  bool _isLoading = true;
  bool _isCheckingIn = false;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  bool get _todayChecked => _stats?['today_checked'] == true;
  int get _currentStreak => _stats?['current_streak'] as int? ?? 0;
  int get _monthCount => _stats?['month_count'] as int? ?? 0;
  int get _totalDays => _stats?['total_days'] as int? ?? 0;
  int get _lotteryChances => _stats?['lottery_chances'] as int? ?? 0;
  int get _streakInCycle => _currentStreak % 7 == 0 && _currentStreak > 0 ? 7 : _currentStreak % 7;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchStats(), _fetchCalendar(), _fetchRanking()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _dio.get('/user/check-in/stats');
      if (res.data['success'] == true) {
        setState(() => _stats = res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _fetchCalendar() async {
    try {
      final res = await _dio.get('/user/check-in/calendar', queryParameters: {'year': _year, 'month': _month});
      if (res.data['success'] == true) {
        final List<dynamic> data = res.data['data'] ?? [];
        setState(() => _calendar = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _fetchRanking() async {
    try {
      final res = await _dio.get('/user/check-in/ranking', queryParameters: {'limit': 10});
      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>? ?? {};
        setState(() {
          _ranking = (data['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          _myRank = data['my_rank'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _doCheckIn() async {
    if (_isCheckingIn || _todayChecked) return;
    setState(() => _isCheckingIn = true);
    try {
      final res = await _dio.post('/user/check-in/');
      if (res.data['success'] == true) {
        setState(() => _stats = res.data['data'] as Map<String, dynamic>);
        await Future.wait([_fetchCalendar(), _fetchRanking()]);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('签到成功！🎉'), duration: Duration(seconds: 2)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('签到失败'), duration: const Duration(seconds: 2)));
      }
    }
    setState(() => _isCheckingIn = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('每日签到')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 签到卡片
                  _buildHeroCard(isDark),
                  const SizedBox(height: 16),
                  // 统计数据
                  _buildStatsRow(isDark),
                  const SizedBox(height: 16),
                  // 日历
                  _buildCalendar(isDark),
                  const SizedBox(height: 16),
                  // 排行榜
                  _buildRanking(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text('$_currentStreak', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text('连续签到天数', style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _todayChecked || _isCheckingIn ? null : _doCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: _todayChecked ? Colors.white24 : Colors.white,
                foregroundColor: _todayChecked ? Colors.white70 : AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              child: _isCheckingIn
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_todayChecked ? '✓ 今日已签到' : '立即签到', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakProgress(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('7天连续签到', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
              Text('第 $_streakInCycle / 7 天', style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black45)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (i) {
              final done = i < _streakInCycle;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                  height: 6,
                  decoration: BoxDecoration(
                    color: done ? AppColors.primary : (isDark ? Colors.white12 : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        _statCard('连续签到', '$_currentStreak', isDark),
        const SizedBox(width: 8),
        _statCard('本月累计', '$_monthCount', isDark),
        const SizedBox(width: 8),
        _statCard('总签到', '$_totalDays', isDark),
      ],
    );
  }

  Widget _statCard(String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black45)),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(bool isDark) {
    final today = '${_year.toString()}-${_month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // 月份导航
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
              Text('$_year年$_month月', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
            ],
          ),
          const SizedBox(height: 8),
          // 星期标题
          Row(
            children: ['日', '一', '二', '三', '四', '五', '六'].map((d) => Expanded(
              child: Center(child: Text(d, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38))),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // 日历格子
          ..._buildCalendarRows(today, isDark),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarRows(String today, bool isDark) {
    final firstDay = DateTime(_year, _month, 1);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sunday

    final checkedDates = <String>{};
    for (final day in _calendar) {
      if (day['checked'] == true) {
        checkedDates.add(day['date'] as String? ?? '');
      }
    }

    final rows = <Widget>[];
    int dayNum = 1;
    for (int week = 0; week < 6; week++) {
      if (dayNum > daysInMonth) break;
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        if (week == 0 && col < startWeekday || dayNum > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 36)));
        } else {
          final dateStr = '$_year-${_month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
          final isChecked = checkedDates.contains(dateStr);
          final isToday = dateStr == today;

          cells.add(Expanded(
            child: GestureDetector(
              onTap: isToday && !isChecked ? _doCheckIn : null,
              child: Container(
                height: 36,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isChecked ? AppColors.primary : (isToday ? AppColors.primary.withAlpha(30) : Colors.transparent),
                  shape: BoxShape.circle,
                  border: isToday && !isChecked ? Border.all(color: AppColors.primary, width: 1.5) : null,
                ),
                child: Center(
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                      color: isChecked ? Colors.white : (isToday ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87)),
                    ),
                  ),
                ),
              ),
            ),
          ));
          dayNum++;
        }
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  void _prevMonth() {
    setState(() {
      _month--;
      if (_month < 1) { _month = 12; _year--; }
    });
    _fetchCalendar();
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) { _month = 1; _year++; }
    });
    _fetchCalendar();
  }

  Widget _buildRanking(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB800), size: 20),
              const SizedBox(width: 6),
              Text('连续签到排行榜', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
              const Spacer(),
              if (_myRank > 0)
                Text('我的排名: $_myRank', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black45)),
            ],
          ),
          const SizedBox(height: 12),
          if (_ranking.isEmpty)
            Center(child: Text('暂无数据', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)))
          else
            ...List.generate(_ranking.length, (i) {
              final item = _ranking[i];
              final nickname = item['nickname'] as String? ?? '用户';
              final avatar = item['avatar'] as String?;
              final streak = item['streak'] as int? ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: i < 3 ? const Color(0xFFFFB800) : (isDark ? Colors.white60 : Colors.black45),
                        ),
                      ),
                    ),
                    AvatarWidget(url: avatar, name: nickname, size: 32),
                    const SizedBox(width: 10),
                    Expanded(child: Text(nickname, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87))),
                    Text('$streak天', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
