import 'package:intl/intl.dart';
import '../../models/app_settings.dart';

class DateFormatter {
  static String formatTime(DateTime time, TimeFormatSetting format) {
    if (format == TimeFormatSetting.h12) {
      return DateFormat('h:mm a').format(time);
    }
    return DateFormat('HH:mm').format(time);
  }

  static String formatHourOnly(DateTime time, TimeFormatSetting format) {
    if (format == TimeFormatSetting.h12) {
      return DateFormat('ha').format(time);
    }
    return DateFormat('HH:00').format(time);
  }

  static String formatFullDate(DateTime time) {
    return DateFormat('EEEE, d MMMM yyyy').format(time);
  }

  static String formatShortDate(DateTime time) {
    return DateFormat('EEE, d MMM').format(time);
  }

  static String formatDayOfWeek(DateTime time) {
    return DateFormat('EEEE').format(time);
  }

  static String formatDayShort(DateTime time) {
    return DateFormat('EEE').format(time);
  }

  static String formatUpdatedAgo(DateTime fetchedAt) {
    final diff = DateTime.now().difference(fetchedAt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, HH:mm').format(fetchedAt);
  }
}
