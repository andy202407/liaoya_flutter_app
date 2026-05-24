import 'package:flutter_test/flutter_test.dart';
import 'package:liaoya_app/utils/time_utils.dart';

void main() {
  group('TimeUtils', () {
    group('shanghaiNow', () {
      test('returns UTC+8 time regardless of device timezone', () {
        final shanghaiTime = TimeUtils.shanghaiNow();
        final utcNow = DateTime.now().toUtc();
        final expectedShanghai = utcNow.add(const Duration(hours: 8));

        // Allow 1 second tolerance for test execution time
        expect(
          shanghaiTime.difference(expectedShanghai).inSeconds.abs(),
          lessThanOrEqualTo(1),
        );
      });

      test('returned DateTime is in UTC (for consistent comparison)', () {
        final shanghaiTime = TimeUtils.shanghaiNow();
        expect(shanghaiTime.isUtc, isTrue);
      });
    });

    group('parseAsShanghai', () {
      test('parses standard datetime string as Shanghai time', () {
        final result = TimeUtils.parseAsShanghai('2024-01-02 08:30:00');
        expect(result.year, 2024);
        expect(result.month, 1);
        expect(result.day, 2);
        expect(result.hour, 8);
        expect(result.minute, 30);
        expect(result.second, 0);
        expect(result.isUtc, isTrue);
      });

      test('parses ISO format with T separator', () {
        final result = TimeUtils.parseAsShanghai('2024-06-15T14:20:30');
        expect(result.year, 2024);
        expect(result.month, 6);
        expect(result.day, 15);
        expect(result.hour, 14);
        expect(result.minute, 20);
        expect(result.second, 30);
      });

      test('strips Z suffix and treats as Shanghai time', () {
        final result = TimeUtils.parseAsShanghai('2024-01-02T08:00:00Z');
        expect(result.hour, 8);
        expect(result.isUtc, isTrue);
      });

      test('strips timezone offset and treats as Shanghai time', () {
        final result = TimeUtils.parseAsShanghai('2024-01-02T08:00:00+08:00');
        expect(result.hour, 8);
        expect(result.isUtc, isTrue);
      });

      test('handles whitespace in input', () {
        final result = TimeUtils.parseAsShanghai('  2024-01-02 08:00:00  ');
        expect(result.year, 2024);
        expect(result.hour, 8);
      });
    });

    group('formatTime', () {
      test('returns empty string for null input', () {
        expect(TimeUtils.formatTime(null), '');
      });

      test('returns empty string for empty string input', () {
        expect(TimeUtils.formatTime(''), '');
      });

      test('returns empty string for invalid time string', () {
        expect(TimeUtils.formatTime('not-a-date'), '');
      });

      test('shows HH:mm for today', () {
        // Create a time string that represents "today" in Shanghai time
        final now = TimeUtils.shanghaiNow();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 14:30:00';
        final result = TimeUtils.formatTime(todayStr);
        expect(result, '14:30');
      });

      test('shows 昨天 HH:mm for yesterday', () {
        final now = TimeUtils.shanghaiNow();
        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayStr =
            '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')} 09:15:00';
        final result = TimeUtils.formatTime(yesterdayStr);
        expect(result, '昨天 09:15');
      });

      test('shows MM-DD HH:mm for same year older dates', () {
        final now = TimeUtils.shanghaiNow();
        // Use a date that's definitely in the same year but more than 1 day ago
        final olderDate = now.subtract(const Duration(days: 30));
        final olderStr =
            '${olderDate.year}-${olderDate.month.toString().padLeft(2, '0')}-${olderDate.day.toString().padLeft(2, '0')} 16:45:00';
        final result = TimeUtils.formatTime(olderStr);
        final expectedMonth = olderDate.month.toString().padLeft(2, '0');
        final expectedDay = olderDate.day.toString().padLeft(2, '0');
        expect(result, '$expectedMonth-$expectedDay 16:45');
      });

      test('shows YYYY-MM-DD HH:mm for different year', () {
        final result = TimeUtils.formatTime('2020-03-15 20:00:00');
        expect(result, '2020-03-15 20:00');
      });

      test('pads single digit hours and minutes', () {
        final now = TimeUtils.shanghaiNow();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 08:05:00';
        final result = TimeUtils.formatTime(todayStr);
        expect(result, '08:05');
      });
    });
  });
}
