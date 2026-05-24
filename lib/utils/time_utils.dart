/// 统一时间工具类
///
/// 所有用户可见的时间显示通过此工具类处理，确保统一使用上海时间 (UTC+8)。
/// 使用固定 UTC+8 偏移量实现，无需额外依赖包。
///
/// Bug_Condition: DateTime.parse() 和 DateTime.now() 依赖设备本地时区
/// Expected_Behavior: 所有用户可见时间通过 TimeUtils 统一为上海时间
class TimeUtils {
  TimeUtils._();

  /// 上海时区固定偏移量: UTC+8
  static const Duration shanghaiOffset = Duration(hours: 8);

  /// 获取当前上海时间
  ///
  /// 通过 UTC 时间加上固定 8 小时偏移量得到上海时间，
  /// 不依赖设备本地时区设置。
  static DateTime shanghaiNow() {
    return DateTime.now().toUtc().add(shanghaiOffset);
  }

  /// 将后端返回的无时区标记时间字符串解析为上海时间
  ///
  /// 后端返回的时间字符串格式如 "2024-01-02 08:00:00"，
  /// 没有时区标记，应视为上海时间 (UTC+8)。
  /// 返回的 DateTime 对象表示的绝对时间点与上海时间一致。
  ///
  /// [timeStr] 后端返回的时间字符串，支持格式:
  ///   - "2024-01-02 08:00:00"
  ///   - "2024-01-02T08:00:00"
  ///   - "2024-01-02T08:00:00Z" (会忽略Z标记，视为上海时间)
  static DateTime parseAsShanghai(String timeStr) {
    // 移除可能的 Z 后缀，因为后端返回的时间实际是上海时间
    String cleaned = timeStr.trim();
    if (cleaned.endsWith('Z') || cleaned.endsWith('z')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }

    // 移除可能的时区偏移信息 (如 +08:00)
    final tzPattern = RegExp(r'[+-]\d{2}:\d{2}$');
    cleaned = cleaned.replaceAll(tzPattern, '');

    // 解析为无时区的 DateTime（此时 DateTime 的值就是上海时间的时分秒）
    final parsed = DateTime.parse(cleaned);

    // 返回一个 UTC DateTime，其 UTC 值等于上海时间的显示值
    // 这样在与 shanghaiNow() 比较时可以直接对比
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
    );
  }

  /// 统一时间格式化
  ///
  /// 根据时间与当前上海时间的关系，返回不同格式:
  /// - 今天: "HH:mm"
  /// - 昨天: "昨天 HH:mm"
  /// - 同年其他日期: "MM-DD HH:mm"
  /// - 不同年: "YYYY-MM-DD HH:mm"
  ///
  /// 所有日期判断基于上海时间，确保所有设备显示一致。
  static String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final time = parseAsShanghai(timeStr);
      final now = shanghaiNow();

      // 基于上海时间的日期（年月日）进行比较
      final timeDate = DateTime.utc(time.year, time.month, time.day);
      final nowDate = DateTime.utc(now.year, now.month, now.day);
      final diffDays = nowDate.difference(timeDate).inDays;

      final hourStr = time.hour.toString().padLeft(2, '0');
      final minuteStr = time.minute.toString().padLeft(2, '0');

      if (diffDays == 0) {
        // 今天: 只显示时间
        return '$hourStr:$minuteStr';
      } else if (diffDays == 1) {
        // 昨天
        return '昨天 $hourStr:$minuteStr';
      } else if (time.year == now.year) {
        // 同年: MM-DD HH:mm
        final monthStr = time.month.toString().padLeft(2, '0');
        final dayStr = time.day.toString().padLeft(2, '0');
        return '$monthStr-$dayStr $hourStr:$minuteStr';
      } else {
        // 不同年: YYYY-MM-DD HH:mm
        final monthStr = time.month.toString().padLeft(2, '0');
        final dayStr = time.day.toString().padLeft(2, '0');
        return '${time.year}-$monthStr-$dayStr $hourStr:$minuteStr';
      }
    } catch (e) {
      return '';
    }
  }
}
