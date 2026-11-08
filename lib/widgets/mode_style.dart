import 'package:flutter/material.dart';

import '../models/journey.dart';

/// Colours and icons per mode, following the Transport for NSW palette.
class ModeStyle {
  final Color color;
  final IconData icon;
  final String label;
  const ModeStyle(this.color, this.icon, this.label);

  static ModeStyle of(TransportMode m) {
    switch (m) {
      case TransportMode.train:
        return const ModeStyle(Color(0xFFF6891F), Icons.train, 'Train');
      case TransportMode.metro:
        return const ModeStyle(Color(0xFF168388), Icons.subway, 'Metro');
      case TransportMode.lightRail:
        return const ModeStyle(Color(0xFFE4022D), Icons.tram, 'Light rail');
      case TransportMode.bus:
        return const ModeStyle(Color(0xFF00B5EF), Icons.directions_bus, 'Bus');
      case TransportMode.schoolBus:
        return const ModeStyle(Color(0xFF00B5EF), Icons.directions_bus_filled, 'School bus');
      case TransportMode.coach:
        return const ModeStyle(Color(0xFF742282), Icons.airport_shuttle, 'Coach');
      case TransportMode.ferry:
        return const ModeStyle(Color(0xFF5AB031), Icons.directions_boat, 'Ferry');
      case TransportMode.walk:
        return const ModeStyle(Color(0xFF757575), Icons.directions_walk, 'Walk');
      case TransportMode.other:
        return const ModeStyle(Color(0xFF455A64), Icons.commute, 'Service');
    }
  }
}

IconData favouriteIcon(String key) {
  switch (key) {
    case 'home':
      return Icons.home;
    case 'work':
      return Icons.work;
    case 'school':
      return Icons.school;
    case 'gym':
      return Icons.fitness_center;
    case 'food':
      return Icons.restaurant;
    default:
      return Icons.star;
  }
}

const favouriteIconKeys = ['home', 'work', 'school', 'gym', 'food', 'star'];
