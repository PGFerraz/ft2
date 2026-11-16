import 'entities.dart';

/// Teste de sobreposição de intervalos semiabertos [aInicio, aFim) e
/// [bInicio, bFim), conforme a Seção 2.4 (ALLEN, 1983).
bool overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
  return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}

class Conflict {
  const Conflict(this.first, this.second);

  final FixedEvent first;
  final FixedEvent second;

  DateTime get overlapStart =>
      first.start.isAfter(second.start) ? first.start : second.start;
  DateTime get overlapEnd =>
      first.end.isBefore(second.end) ? first.end : second.end;
  Duration get overlap => overlapEnd.difference(overlapStart);
}

/// Detecta todos os pares de compromissos fixos que se sobrepõem (RF03).
///
/// Os compromissos são ordenados pelo início; para cada um, só é preciso
/// comparar com os seguintes que começam antes do seu fim.
List<Conflict> detectConflicts(Iterable<FixedEvent> events) {
  final sorted = events.toList()
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.end.compareTo(b.end);
    });
  final conflicts = <Conflict>[];
  for (var i = 0; i < sorted.length; i++) {
    final a = sorted[i];
    for (var j = i + 1; j < sorted.length; j++) {
      final b = sorted[j];
      if (!b.start.isBefore(a.end)) break;
      if (overlaps(a.start, a.end, b.start, b.end)) {
        conflicts.add(Conflict(a, b));
      }
    }
  }
  return conflicts;
}
