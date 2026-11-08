import 'package:flutter/material.dart';

import '../models/journey.dart';
import 'countdown.dart';
import 'mode_style.dart';

/// Compact row like:  🚶 4  ›  [🚌 333]  ›  [🚆 T1]
class LegChips extends StatelessWidget {
  const LegChips({super.key, required this.legs});
  final List<Leg> legs;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < legs.length; i++) {
      final l = legs[i];
      // skip tiny transfer walks
      if (l.isWalk && l.duration.inMinutes < 1 && legs.length > 1) continue;
      if (children.isNotEmpty) {
        children.add(Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500));
      }
      children.add(LegChip(leg: l));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 4,
      children: children,
    );
  }
}

class LegChip extends StatelessWidget {
  const LegChip({super.key, required this.leg});
  final Leg leg;

  @override
  Widget build(BuildContext context) {
    final s = ModeStyle.of(leg.mode);
    if (leg.isWalk) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: 18, color: s.color),
        Text(formatDuration(leg.duration).replaceAll(' min', ''),
            style: TextStyle(fontSize: 12, color: s.color)),
      ]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: 15, color: Colors.white),
        const SizedBox(width: 3),
        Text(leg.routeNumber.isEmpty ? s.label : leg.routeNumber,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}
