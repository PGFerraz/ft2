import 'package:flutter/material.dart';

import '../format.dart';

/// Arredonda um horário escolhido para o múltiplo de 15 minutos mais próximo.
TimeOfDay roundToQuarter(TimeOfDay t) {
  final total = ((t.hour * 60 + t.minute) / 15).round() * 15;
  final clamped = total.clamp(0, 23 * 60 + 45);
  return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
}

class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 2),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text('${fmtDayLabel(value)} · ${fmtDate(value)}/${value.year}'),
      ),
    );
  }
}

class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
          helpText: 'Horários são arredondados para 15 min',
        );
        if (picked != null) onChanged(roundToQuarter(picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule, size: 18),
        ),
        child: Text('${two(value.hour)}:${two(value.minute)}'),
      ),
    );
  }
}

/// Coloca dois campos lado a lado em telas largas e empilhados no celular.
class FieldPair extends StatelessWidget {
  const FieldPair({super.key, required this.first, required this.second, this.breakpoint = 480});

  final Widget first;
  final Widget second;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return Column(children: [first, const SizedBox(height: 16), second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: first), const SizedBox(width: 12), Expanded(child: second)],
      );
    });
  }
}
