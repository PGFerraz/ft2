import 'package:agenda_ia/domain/conflicts.dart';
import 'package:agenda_ia/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

FixedEvent _event(String id, int startHour, int startMin, int endHour, int endMin) {
  return FixedEvent(
    id: id,
    title: id,
    start: DateTime(2026, 11, 11, startHour, startMin),
    end: DateTime(2026, 11, 11, endHour, endMin),
  );
}

void main() {
  group('overlaps', () {
    final a = DateTime(2026, 11, 11, 9);
    final b = DateTime(2026, 11, 11, 10);
    final c = DateTime(2026, 11, 11, 11);

    test('intervalos encostados não se sobrepõem (intervalo semiaberto)', () {
      expect(overlaps(a, b, b, c), isFalse);
      expect(overlaps(b, c, a, b), isFalse);
    });

    test('sobreposição parcial e contenção são detectadas', () {
      expect(overlaps(a, c, b, c), isTrue);
      expect(overlaps(a, c, a.add(const Duration(minutes: 15)), b), isTrue);
    });

    test('intervalos disjuntos não se sobrepõem', () {
      expect(overlaps(a, b, c, c.add(const Duration(hours: 1))), isFalse);
    });
  });

  group('detectConflicts', () {
    test('lista vazia ou sem sobreposição não gera conflitos', () {
      expect(detectConflicts([]), isEmpty);
      expect(
        detectConflicts([_event('A', 8, 0, 9, 0), _event('B', 9, 0, 10, 0)]),
        isEmpty,
      );
    });

    test('encontra todos os pares em conflito, independentemente da ordem', () {
      final events = [
        _event('C', 13, 0, 14, 0),
        _event('A', 9, 0, 12, 0),
        _event('B', 10, 0, 11, 0),
        _event('D', 11, 30, 13, 30),
      ];
      final pairs = detectConflicts(events)
          .map((c) => '${c.first.id}-${c.second.id}')
          .toSet();
      expect(pairs, {'A-B', 'A-D', 'D-C'});
    });

    test('calcula a duração da sobreposição', () {
      final conflict = detectConflicts(
          [_event('A', 9, 0, 10, 0), _event('B', 9, 30, 11, 0)]).single;
      expect(conflict.overlap, const Duration(minutes: 30));
    });
  });
}
