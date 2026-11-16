const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _months = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String two(int n) => n.toString().padLeft(2, '0');

String fmtTime(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

String fmtMinutesOfDay(int minutes) => '${two(minutes ~/ 60)}:${two(minutes % 60)}';

String fmtDate(DateTime t) => '${two(t.day)}/${two(t.month)}';

String fmtWeekday(DateTime t) => _weekdays[t.weekday - 1];

/// "qua, 11 nov"
String fmtDayLabel(DateTime t) => '${fmtWeekday(t)}, ${t.day} ${_months[t.month - 1]}';

/// "Hoje", "Amanhã" ou "sex, 13 nov".
String fmtRelativeDay(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Amanhã';
  if (diff == -1) return 'Ontem';
  return fmtDayLabel(d);
}

/// "qua, 11 nov · 14:30"
String fmtDateTime(DateTime t, DateTime now) => '${fmtRelativeDay(t, now)} · ${fmtTime(t)}';

String fmtDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${two(m)}';
}

String fmtNumber(double value, {int decimals = 1}) {
  final rounded = value.toStringAsFixed(decimals);
  final trimmed = rounded.contains('.')
      ? rounded.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : rounded;
  return trimmed.replaceAll('.', ',');
}

String fmtMs(double ms) => ms < 1 ? '${fmtNumber(ms, decimals: 2)} ms' : '${fmtNumber(ms)} ms';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
