import 'package:latlong2/latlong.dart';

/// A location the user can travel to/from: a stop, address or point of interest.
class Place {
  final String id; // TfNSW location id (stop id, or coordinate string)
  final String name;
  final String? subtitle;
  final double lat;
  final double lng;
  final String type; // stop, street, poi, singlehouse, coord, ...
  final String? label; // favourite label e.g. "Home"
  final String icon; // favourite icon key: home, work, star, school, gym

  const Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.subtitle,
    this.type = 'any',
    this.label,
    this.icon = 'star',
  });

  LatLng get latLng => LatLng(lat, lng);

  String get displayName => label?.isNotEmpty == true ? label! : name;

  /// Whether the trip planner should be given this as a stop id or a coordinate.
  bool get isStop => type == 'stop' || type == 'platform';

  /// Value for the trip planner's name_origin / name_destination parameter.
  String get tripPlannerName => isStop ? id : '$lng:$lat:EPSG:4326';
  String get tripPlannerType => isStop ? 'any' : 'coord';

  Place copyWith({String? label, String? icon}) => Place(
        id: id,
        name: name,
        subtitle: subtitle,
        lat: lat,
        lng: lng,
        type: type,
        label: label ?? this.label,
        icon: icon ?? this.icon,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'lat': lat,
        'lng': lng,
        'type': type,
        'label': label,
        'icon': icon,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: j['id'] as String,
        name: j['name'] as String,
        subtitle: j['subtitle'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        type: j['type'] as String? ?? 'any',
        label: j['label'] as String?,
        icon: j['icon'] as String? ?? 'star',
      );

  /// Parse an entry from the TfNSW stop_finder `locations` array.
  static Place? fromStopFinder(Map<String, dynamic> j) {
    final coord = j['coord'] as List?;
    if (coord == null || coord.length < 2) return null;
    final parent = j['parent'] as Map<String, dynamic>?;
    final disassembled = j['disassembledName'] as String?;
    final full = j['name'] as String? ?? '';
    return Place(
      id: j['id'] as String? ?? full,
      name: disassembled ?? full,
      subtitle: parent?['name'] as String? ?? (disassembled != null ? full : null),
      lat: (coord[0] as num).toDouble(),
      lng: (coord[1] as num).toDouble(),
      type: j['type'] as String? ?? 'any',
    );
  }
}
