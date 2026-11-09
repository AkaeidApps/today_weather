class Place {
  const Place({
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    this.admin1 = '',
    this.timezone = 'auto',
  });

  final String name;
  final String country;
  final String admin1;
  final double lat;
  final double lon;
  final String timezone;

  String get label {
    if (country.isEmpty) return name;
    if (admin1.isNotEmpty && admin1 != name && admin1 != country) {
      return '$name, $admin1, $country';
    }
    return '$name, $country';
  }

  String get shortLabel => country.isEmpty ? name : '$name, $country';

  Map<String, dynamic> toJson() => {
    'name': name,
    'country': country,
    'admin1': admin1,
    'lat': lat,
    'lon': lon,
    'timezone': timezone,
  };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    name: json['name'] as String? ?? 'Unknown',
    country: json['country'] as String? ?? '',
    admin1: json['admin1'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
    lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
    timezone: json['timezone'] as String? ?? 'auto',
  );

  /// String serialization for SharedPreferences
  String toSerializedString() =>
      '$name|$country|$lat|$lon|$timezone|$admin1';

  static Place? fromSerializedString(String raw) {
    try {
      final parts = raw.split('|');
      if (parts.length < 4) return null;
      return Place(
        name: parts[0],
        country: parts[1],
        lat: double.parse(parts[2]),
        lon: double.parse(parts[3]),
        timezone: parts.length > 4 ? parts[4] : 'auto',
        admin1: parts.length > 5 ? parts[5] : '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Place &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          country == other.country &&
          (lat - other.lat).abs() < 0.001 &&
          (lon - other.lon).abs() < 0.001;

  @override
  int get hashCode => Object.hash(name, country, (lat * 100).round(), (lon * 100).round());
}
