import 'package:flutter/material.dart';

import '../../domain/entities.dart';
import '../theme.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge(this.priority, {super.key, this.compact = false});

  final int priority;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = priorityColors(context, priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        compact ? 'P$priority' : priorityLabel(priority),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      TaskStatus.concluida => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      TaskStatus.atrasada => (scheme.errorContainer, scheme.onErrorContainer),
      TaskStatus.alocada => (scheme.primaryContainer, scheme.onPrimaryContainer),
      TaskStatus.pendente => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

/// Grade de métricas que se ajusta à largura disponível.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children, this.minTileWidth = 140});

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 8.0;
      final columns =
          ((constraints.maxWidth + gap) / (minTileWidth + gap)).floor().clamp(1, children.length);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: width, child: c)],
      );
    });
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle!,
                style: text.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(builder: (context, constraints) {
        if (trailing == null) return SizedBox(width: double.infinity, child: heading);
        // Em telas estreitas o elemento à direita desce para baixo do título.
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 8), trailing!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: heading), const SizedBox(width: 8), trailing!],
        );
      }),
    );
  }
}

/// Limita a largura do conteúdo em telas grandes e aplica a margem lateral.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 1100});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width < Breakpoints.medium ? 16.0 : 24.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: EdgeInsets.symmetric(horizontal: gutter), child: child),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: scheme.outline),
          const SizedBox(height: 12),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
