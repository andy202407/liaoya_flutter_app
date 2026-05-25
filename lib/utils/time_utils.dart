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

  /// 获取当前上海时间的 ISO8601 字符串（不带时区后缀）
  ///
  /// 用于本地生成消息时间戳，确保与后端返回的格式一致。
  /// 输出格式: "2026-05-25T16:01:00.000"
  static String nowIso8601() {
    final now = shanghaiNow();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
  }

  /// 将后端返回的时间字符串解析为上海时间
  ///
  /// 支持格式:
  ///   - "2024-01-02 08:00:00" (无时区，视为上海时间)
  ///   - "2024-01-02T08:00:00" (无时区，视为上海时间)
  ///   - "2024-01-02T08:00:00Z" (UTC时间，转换为上海时间)
  ///   - "2024-01-02T08:00:00+08:00" (带时区，转换为上海时间)
  static DateTime parseAsShanghai(String timeStr) {
    String cleaned = timeStr.trim();
    if (cleaned.isEmpty) return DateTime.utc(2000);

    // 尝试用 DateTime.parse 解析（它能正确处理 Z 和 +08:00）
    try {
      final parsed = DateTime.parse(cleaned);
      // DateTime.parse 会根据时区信息返回正确的绝对时间
      // 如果有时区信息（Z 或 +xx:xx），parsed.isUtc 为 true
      // 如果没有时区信息，parsed.isUtc 为 false（本地时间）

      DateTime utcTime;
      if (parsed.isUtc) {
        // 带 Z 或带时区偏移的字符串，DateTime.parse 已正确转为 UTC
        utcTime = parsed;
      } else {
        // 无时区标记，视为上海时间，减去8小时得到UTC
        utcTime = parsed.subtract(shanghaiOffset);
      }

      // 转换为上海时间的显示值（UTC + 8小时）
      final shanghai = utcTime.add(shanghaiOffset);
      return DateTime.utc(
        shanghai.year,
        shanghai.month,
        shanghai.day,
        shanghai.hour,
        shanghai.minute,
        shanghai.second,
        shanghai.millisecond,
      );
    } catch (e) {
      // 解析失败，返回一个默认值
      return DateTime.utc(2000);
    }
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
