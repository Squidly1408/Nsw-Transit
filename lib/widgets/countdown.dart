import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatDuration(Duration d) {
  final mins = d.inMinutes;
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60, m = mins % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String formatClock(DateTime? t) => t == null ? '--' : DateFormat('h:mm a').format(t);

/// "Now", "3 min", "1h 5m" — until [target]. Rebuilds itself every second.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.target, this.style, this.prefix = ''});
  final DateTime? target;
  final TextStyle? style;
  final String prefix;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.target;
    if (t == null) return Text('--', style: widget.style);
    final diff = t.difference(DateTime.now());
    final String text;
    if (diff.inSeconds <= 30) {
      text = diff.inSeconds < -60 ? 'Departed' : 'Now';
    } else if (diff.inMinutes < 1) {
      text = '${widget.prefix}<1 min';
    } else {
      text = '${widget.prefix}${formatDuration(diff)}';
    }
    final urgent = diff.inMinutes < 3;
    return Text(
      text,
      style: (widget.style ?? const TextStyle()).copyWith(
        color: urgent ? Colors.red.shade700 : null,
      ),
    );
  }
}

/// Small "On time" / "3 min late" badge with a realtime indicator.
class DelayBadge extends StatelessWidget {
  const DelayBadge({super.key, required this.delay, required this.realtime});
  final Duration? delay;
  final bool realtime;

  @override
  Widget build(BuildContext context) {
    if (!realtime) {
      return Text('Scheduled', style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
    }
    final mins = delay?.inMinutes ?? 0;
    final (String text, Color color) = mins >= 1
        ? ('$mins min late', Colors.red.shade700)
        : mins <= -1
            ? ('${-mins} min early', Colors.blue.shade700)
            : ('On time', Colors.green.shade700);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.sensors, size: 13, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}
