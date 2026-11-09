import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/atmos_theme.dart';
import 'models/background_scene.dart';

void main() => runApp(const AtmosApp(home: WeatherShell()));

const ink = AtmosColors.ink;
const muted = AtmosColors.muted;
const sea = AtmosColors.sea;
const cream = AtmosColors.canvas;

class Place {
  const Place(
    this.name,
    this.country,
    this.lat,
    this.lon, [
    this.timezone = 'auto',
  ]);
  final String name, country, timezone;
  final double lat, lon;
  String get label => '$name, $country';
}

class WeatherData {
  WeatherData(this.json);
  final Map<String, dynamic> json;

  Map<String, dynamic> get current =>
      Map<String, dynamic>.from(json['current'] ?? {});
  Map<String, dynamic> get daily =>
      Map<String, dynamic>.from(json['daily'] ?? {});
  Map<String, dynamic> get hourly =>
      Map<String, dynamic>.from(json['hourly'] ?? {});

  double get temp => (current['temperature_2m'] as num?)?.toDouble() ?? 0;
  double get feels =>
      (current['apparent_temperature'] as num?)?.toDouble() ?? temp;
  int get code => (current['weather_code'] as num?)?.toInt() ?? 0;
  double get wind => (current['wind_speed_10m'] as num?)?.toDouble() ?? 0;
  double get gust => (current['wind_gusts_10m'] as num?)?.toDouble() ?? wind;
  int get bearing => (current['wind_direction_10m'] as num?)?.toInt() ?? 0;
  int get humidity => (current['relative_humidity_2m'] as num?)?.toInt() ?? 0;
  double get rain => (current['precipitation'] as num?)?.toDouble() ?? 0;
  double get pressure => (current['pressure_msl'] as num?)?.toDouble() ?? 0;
  double get cloud => (current['cloud_cover'] as num?)?.toDouble() ?? 0;
  double get uv => (current['uv_index'] as num?)?.toDouble() ?? 0;
  double get visibility =>
      ((current['visibility'] as num?)?.toDouble() ?? 0) / 1000;
  double get high =>
      ((daily['temperature_2m_max'] as List?)?.first as num?)?.toDouble() ??
      temp;
  double get low =>
      ((daily['temperature_2m_min'] as List?)?.first as num?)?.toDouble() ??
      temp;

  DateTime get localTime =>
      DateTime.tryParse('${current['time'] ?? ''}') ?? DateTime.now();

  DateTime? _dailyTime(String key) {
    final list = daily[key] as List?;
    return list == null || list.isEmpty
        ? null
        : DateTime.tryParse('${list.first}');
  }

  String get timezone => '${json['timezone'] ?? 'UTC'}';
  String get description => weatherText(code);

  bool isDay(Place place) {
    final time = localTime;
    final sr = _dailyTime('sunrise'), ss = _dailyTime('sunset');
    if (sr != null && ss != null) return time.isAfter(sr) && time.isBefore(ss);
    final sunrise = (daily['sunrise'] as List?)?.firstOrNull;
    final sunset = (daily['sunset'] as List?)?.firstOrNull;
    return sunrise != null &&
        sunset != null &&
        time.hour >= DateTime.parse('$sunrise').hour &&
        time.hour < DateTime.parse('$sunset').hour;
  }

  /// Calculates atmospheric background scene based on time of day (Sunrise, Sunset, Moonlight, Day)
  BackgroundScene get automaticScene {
    final time = localTime;
    final sr = _dailyTime('sunrise');
    final ss = _dailyTime('sunset');

    if (sr != null && ss != null) {
      final sunriseStart = sr.subtract(const Duration(minutes: 50));
      final sunriseEnd = sr.add(const Duration(minutes: 60));
      final sunsetStart = ss.subtract(const Duration(minutes: 60));
      final sunsetEnd = ss.add(const Duration(minutes: 50));

      if (time.isAfter(sunriseStart) && time.isBefore(sunriseEnd)) {
        return BackgroundScene.sunrise;
      }
      if (time.isAfter(sunsetStart) && time.isBefore(sunsetEnd)) {
        return BackgroundScene.sunset;
      }
      if (time.isAfter(sr) && time.isBefore(ss)) {
        return BackgroundScene.sunrise; // daytime horizon
      }
      return BackgroundScene.moonlight;
    }

    final hour = time.hour;
    if (hour >= 5 && hour <= 7) return BackgroundScene.sunrise;
    if (hour >= 17 && hour <= 19) return BackgroundScene.sunset;
    if (hour >= 20 || hour < 5) return BackgroundScene.moonlight;
    return BackgroundScene.sunrise;
  }

  String get sunrise => '${(daily['sunrise'] as List?)?.firstOrNull ?? '—'}';
  String get sunset => '${(daily['sunset'] as List?)?.firstOrNull ?? '—'}';
}

String weatherText(int code) => switch (code) {
  0 => 'Clear sky',
  1 => 'Mainly clear',
  2 => 'Partly cloudy',
  3 => 'Overcast',
  45 || 48 => 'Foggy',
  51 || 53 || 55 => 'Drizzle',
  56 || 57 => 'Freezing drizzle',
  61 || 63 || 65 => 'Rain',
  66 || 67 => 'Freezing rain',
  71 || 73 || 75 || 77 => 'Snow',
  80 || 81 || 82 => 'Rain showers',
  85 || 86 => 'Snow showers',
  95 || 96 || 99 => 'Thunderstorm',
  _ => 'Weather data',
};

IconData weatherIcon(int code, {bool night = false}) => switch (code) {
  0 => night ? Icons.nightlight_round : Icons.wb_sunny_rounded,
  1 || 2 => night ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded,
  3 || 45 || 48 => Icons.cloud_rounded,
  51 ||
  53 ||
  55 ||
  61 ||
  63 ||
  65 ||
  80 ||
  81 ||
  82 ||
  95 ||
  96 ||
  99 => Icons.water_drop_rounded,
  71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_rounded,
  _ => Icons.cloud_rounded,
};

/// Smooth 3D tilt, hover scale, cursor, and mouse glow wrapper widget.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.onTap,
    this.enableTilt = true,
    this.padding,
    this.margin,
    this.decoration,
    this.depth = 1.0,
  });

  final Widget child;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool enableTilt;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxDecoration? decoration;
  final double depth;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  Offset _mousePos = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (e) => setState(() {
        _hovered = true;
        _mousePos = e.localPosition;
      }),
      onHover: (e) => setState(() => _mousePos = e.localPosition),
      onExit: (_) => setState(() {
        _hovered = false;
        _mousePos = Offset.zero;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 300.0;
            final height = constraints.hasBoundedHeight && constraints.maxHeight > 0
                ? constraints.maxHeight
                : 200.0;

            final dx = _hovered && widget.enableTilt
                ? ((_mousePos.dx / width) - 0.5) * widget.depth
                : 0.0;
            final dy = _hovered && widget.enableTilt
                ? ((_mousePos.dy / height) - 0.5) * widget.depth
                : 0.0;

            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(-dy * 0.08)
              ..rotateY(dx * 0.08);

            final scale = _pressed
                ? 0.97
                : _hovered
                    ? 1.018
                    : 1.0;

            final baseDeco = widget.decoration ??
                BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: _hovered
                        ? sea.withValues(alpha: 0.40)
                        : const Color(0xffedf0f1),
                    width: _hovered ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _hovered
                          ? sea.withValues(alpha: 0.15)
                          : const Color(0x0a101922),
                      blurRadius: _hovered ? 26 : 16,
                      offset: Offset(0, _hovered ? 10 : 5),
                      spreadRadius: _hovered ? 2 : 0,
                    ),
                  ],
                );

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: widget.margin,
              transform: matrix..scale(scale, scale, 1.0),
              transformAlignment: Alignment.center,
              child: Container(
                padding: widget.padding,
                decoration: baseDeco,
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    widget.child,
                    if (_hovered)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _hovered ? 0.07 : 0.0,
                            child: CustomPaint(
                              painter: _GlowPainter(
                                position: _mousePos,
                                color: sea,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.position, required this.color});
  final Offset position;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.8), Colors.transparent],
      ).createShader(Rect.fromCircle(center: position, radius: size.width * 0.6));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.position != position;
}

class WeatherShell extends StatefulWidget {
  const WeatherShell({super.key});
  @override
  State<WeatherShell> createState() => _WeatherShellState();
}

class _WeatherShellState extends State<WeatherShell> {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
  Place _place = const Place('Dhaka', 'Bangladesh', 23.8103, 90.4125);
  WeatherData? _weather;
  Map<String, dynamic>? _air;
  bool _loading = true,
      _airLoading = true,
      _fahrenheit = false;

  BackgroundMode _bgMode = BackgroundMode.automatic;

  String? _error;
  int _tab = 0;
  final List<Place> _recent = [];
  List<Place> _favorites = [];
  Timer? _searchTimer;
  List<Place> _results = [];
  bool _searching = false;
  final _searchCtl = TextEditingController();

  // Mouse Parallax coordinates for hero sky card
  Offset _heroMouse = Offset.zero;
  bool _heroHovered = false;

  static const pages = [
    'Today',
    'Map',
    'Hourly',
    '7 day',
    'Wind',
    'Air quality',
    'Locations',
    'Compare',
    'About',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fahrenheit = p.getBool('fahrenheit') ?? false;
      final modeIndex = p.getInt('bg_mode') ?? 0;
      _bgMode = BackgroundMode.values[modeIndex.clamp(0, BackgroundMode.values.length - 1)];
      _favorites = (p.getStringList('favorites') ?? [])
          .map(_decodePlace)
          .whereType<Place>()
          .toList();
      final raw = p.getString('place');
      if (raw != null) _place = _decodePlace(raw) ?? _place;
    });
    _load();
  }

  Place? _decodePlace(String raw) {
    try {
      final x = raw.split('|');
      return Place(
        x[0],
        x[1],
        double.parse(x[2]),
        double.parse(x[3]),
        x.length > 4 ? x[4] : 'auto',
      );
    } catch (_) {
      return null;
    }
  }

  String _encodePlace(Place p) =>
      '${p.name}|${p.country}|${p.lat}|${p.lon}|${p.timezone}';

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('fahrenheit', _fahrenheit);
    await p.setInt('bg_mode', _bgMode.index);
    await p.setString('place', _encodePlace(_place));
    await p.setStringList('favorites', _favorites.map(_encodePlace).toList());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _error = null;
    try {
      const url = 'https://api.open-meteo.com/v1/forecast';
      final r = await _dio.get(
        url,
        queryParameters: {
          'latitude': _place.lat,
          'longitude': _place.lon,
          'timezone': 'auto',
          'forecast_days': 7,
          'forecast_hours': 48,
          'current':
              'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,visibility',
          'hourly':
              'temperature_2m,precipitation_probability,precipitation,weather_code,wind_speed_10m,relative_humidity_2m',
          'daily':
              'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,wind_speed_10m_max,uv_index_max',
        },
      );
      if (!mounted) return;
      setState(() => _weather = WeatherData(Map<String, dynamic>.from(r.data)));
      _loadAir();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Weather data is unavailable. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAir() async {
    setState(() => _airLoading = true);
    try {
      final r = await _dio.get(
        'https://air-quality-api.open-meteo.com/v1/air-quality',
        queryParameters: {
          'latitude': _place.lat,
          'longitude': _place.lon,
          'timezone': 'auto',
          'current':
              'european_aqi,us_aqi,pm2_5,pm10,carbon_monoxide,nitrogen_dioxide,ozone,sulphur_dioxide',
        },
      );
      if (mounted) {
        setState(
          () => _air = Map<String, dynamic>.from(r.data['current'] ?? {}),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _air = null);
    } finally {
      if (mounted) setState(() => _airLoading = false);
    }
  }

  Future<void> _choose(Place p) async {
    setState(() {
      _place = p;
      _tab = 0;
      _searching = false;
      _searchCtl.clear();
      _recent.removeWhere((x) => x.label == p.label);
      _recent.insert(0, p);
      if (_recent.length > 6) _recent.removeLast();
    });
    await _persist();
    await _load();
  }

  void _onSearch(String s) {
    _searchTimer?.cancel();
    if (s.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final r = await _dio.get(
          'https://geocoding-api.open-meteo.com/v1/search',
          queryParameters: {
            'name': s.trim(),
            'count': 8,
            'language': 'en',
            'format': 'json',
          },
        );
        final list = (r.data['results'] as List? ?? [])
            .map(
              (x) => Place(
                '${x['name']}',
                '${x['country'] ?? x['admin1'] ?? '—'}',
                (x['latitude'] as num).toDouble(),
                (x['longitude'] as num).toDouble(),
                '${x['timezone'] ?? 'auto'}',
              ),
            )
            .toList();
        if (mounted) setState(() => _results = list);
      } catch (_) {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  Future<void> _gps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Enable location services to use your location.');
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission was not granted. Search for a city instead.',
        );
      }
      final pos = await Geolocator.getCurrentPosition();
      Place here = Place(
        'My location',
        '${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)}',
        pos.latitude,
        pos.longitude,
      );
      try {
        final r = await _dio.get(
          'https://geocoding-api.open-meteo.com/v1/reverse',
          queryParameters: {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'language': 'en',
            'format': 'json',
          },
        );
        final x = (r.data['results'] as List?)?.first;
        if (x != null) {
          here = Place(
            '${x['name']}',
            '${x['country'] ?? ''}',
            pos.latitude,
            pos.longitude,
            '${x['timezone'] ?? 'auto'}',
          );
        }
      } catch (_) {}
      await _choose(here);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String _temp(num n) =>
      '${_fahrenheit ? (n * 9 / 5 + 32).round() : n.round()}°';

  /// Format ISO time strings cleanly (e.g. "2025-02-17T06:23" -> "06:23 AM")
  String _clock(String value) {
    if (value.trim().isEmpty || value == '—') return '—';
    final dt = DateTime.tryParse(value);
    if (dt != null) {
      return DateFormat('h:mm a').format(dt);
    }
    if (value.length >= 16) return value.substring(11, 16);
    return value;
  }

  /// Returns the current active background scene (Sunrise, Sunset, Moonlight/Night, Daytime)
  BackgroundScene get _activeScene {
    if (_bgMode.previewScene != null) {
      return _bgMode.previewScene!;
    }
    if (_weather == null) return BackgroundScene.sunrise;
    return _weather!.automaticScene;
  }

  /// Full screen background gradient based on selected scene
  List<Color> get _fullBgGradients => switch (_activeScene) {
        BackgroundScene.sunrise => [
            const Color(0xff2a1936),
            const Color(0xff542646),
            const Color(0xff8c3848),
            const Color(0xffb84e44),
            const Color(0xffe2774d),
          ],
        BackgroundScene.sunset => [
            const Color(0xff181226),
            const Color(0xff361738),
            const Color(0xff5c1e3d),
            const Color(0xff8a2b45),
            const Color(0xffb53f40),
          ],
        BackgroundScene.moonlight => [
            const Color(0xff09111c),
            const Color(0xff0f192b),
            const Color(0xff16243a),
            const Color(0xff21314a),
          ],
      };

  bool get _isAtmosphericScene => true;

  Color get _textColor => _isAtmosphericScene ? Colors.white : ink;
  Color get _mutedTextColor => _isAtmosphericScene ? Colors.white70 : muted;
  BoxDecoration get _cardGlassDecoration => BoxDecoration(
        color: _isAtmosphericScene
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isAtmosphericScene
              ? Colors.white.withValues(alpha: 0.22)
              : const Color(0xffedf0f1),
        ),
        boxShadow: [
          BoxShadow(
            color: _isAtmosphericScene
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0x0a101922),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 850;
    final fullSky = _fullBgGradients;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: fullSky,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(wide),
              if (_error != null) _errorBanner(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.015, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: wide ? _desktopBody() : _mobileBody(),
                ),
              ),
              if (!wide) _bottomNav(),
            ],
          ),
        ),
      ),
      floatingActionButton: wide
          ? null
          : FloatingActionButton.small(
              onPressed: _gps,
              backgroundColor: _isAtmosphericScene ? Colors.white : ink,
              foregroundColor: _isAtmosphericScene ? ink : Colors.white,
              child: const Icon(Icons.my_location_rounded),
            ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  Widget _header(bool wide) => AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: Colors.white.withValues(alpha: 0.12),
        padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 18, vertical: 13),
        child: Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff3a7bd5), Color(0xff3a6073)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff3a7bd5).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Icon(
                        Icons.wb_sunny_rounded,
                        color: const Color(0xffffd166).withValues(alpha: 0.95),
                        size: 16,
                      ),
                    ),
                    const Icon(
                      Icons.cloud_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).scale(duration: 400.ms),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATMOS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 2.2,
                    color: _textColor,
                  ),
                ),
                Text(
                  'WEATHER',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 3.0,
                    color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            if (wide) ...[
              const SizedBox(width: 35),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(
                      pages.length,
                      (i) => _navLabel(i).animate().fadeIn(
                            delay: Duration(milliseconds: 50 * i),
                            duration: 300.ms,
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            IconButton(
              tooltip: 'Use my location',
              onPressed: _gps,
              icon: Icon(Icons.my_location_rounded, color: _textColor),
            ),
            if (wide)
              IconButton(
                tooltip: 'Temperature units',
                onPressed: () => setState(() {
                  _fahrenheit = !_fahrenheit;
                  _persist();
                }),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _fahrenheit ? '°F' : '°C',
                    key: ValueKey(_fahrenheit),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => setState(() => _tab = 9),
              icon: Icon(Icons.tune_rounded, color: _textColor),
            ),
          ],
        ),
      );

  Widget _navLabel(int i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _tab == i
                ? (_isAtmosphericScene
                    ? Colors.white.withValues(alpha: 0.25)
                    : sea.withValues(alpha: 0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton(
            onPressed: () => setState(() => _tab = i),
            style: TextButton.styleFrom(
              foregroundColor: _tab == i
                  ? (_isAtmosphericScene ? const Color(0xffffd166) : sea)
                  : _mutedTextColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              pages[i],
              style: TextStyle(
                fontWeight: _tab == i ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );

  Widget _bottomNav() => AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: _isAtmosphericScene
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white,
          border: Border(
            top: BorderSide(
              color: _isAtmosphericScene
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xffe9edef),
            ),
          ),
        ),
        child: NavigationBar(
          height: 66,
          selectedIndex: _tab < 5 ? _tab : 0,
          onDestinationSelected: (i) => setState(() => _tab = i),
          backgroundColor: Colors.transparent,
          indicatorColor: _isAtmosphericScene
              ? Colors.white.withValues(alpha: 0.25)
              : sea.withValues(alpha: .14),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined, color: _mutedTextColor),
              selectedIcon: Icon(
                Icons.wb_sunny_rounded,
                color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
              ),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined, color: _mutedTextColor),
              selectedIcon: Icon(
                Icons.map,
                color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
              ),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule, color: _mutedTextColor),
              selectedIcon: Icon(
                Icons.schedule,
                color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
              ),
              label: 'Hourly',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined, color: _mutedTextColor),
              selectedIcon: Icon(
                Icons.calendar_month,
                color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
              ),
              label: '7 day',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu, color: _mutedTextColor),
              selectedIcon: Icon(
                Icons.menu,
                color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
              ),
              label: 'More',
            ),
          ],
        ),
      );

  Widget _mobileBody() => _tab == 4 ? _moreMenu() : _content();

  Widget _moreMenu() => ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Explore Aether',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _textColor,
            ),
          ).animate().fadeIn().slideX(begin: -0.1),
          const SizedBox(height: 18),
          ...List.generate(pages.length - 5, (i) {
            final k = i + 5;
            return HoverCard(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: _cardGlassDecoration,
              onTap: () => setState(() => _tab = k),
              child: ListTile(
                leading: Icon(
                  _pageIcon(k),
                  color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                ),
                title: Text(
                  pages[k],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                trailing: Icon(Icons.chevron_right, color: _mutedTextColor),
              ),
            ).animate().fadeIn(
                  delay: Duration(milliseconds: 60 * i),
                  duration: 350.ms,
                );
          }),
        ],
      );

  IconData _pageIcon(int i) => switch (i) {
        1 => Icons.map_outlined,
        2 => Icons.schedule,
        3 => Icons.calendar_month_outlined,
        4 => Icons.air,
        5 => Icons.blur_on,
        6 => Icons.public,
        7 => Icons.compare_arrows,
        8 => Icons.info_outline,
        _ => Icons.settings_outlined,
      };

  Widget _desktopBody() => Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 265,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              border: Border(
                right: BorderSide(
                  color: _isAtmosphericScene
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xffe9edef),
                ),
              ),
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _searchBox(),
                const SizedBox(height: 24),
                _sideHeading('YOUR WEATHER'),
                ...List.generate(
                  pages.length,
                  (i) => HoverCard(
                    enableTilt: false,
                    margin: const EdgeInsets.only(bottom: 4),
                    borderRadius: 12,
                    onTap: () => setState(() => _tab = i),
                    decoration: BoxDecoration(
                      color: _tab == i
                          ? (_isAtmosphericScene
                              ? Colors.white.withValues(alpha: 0.25)
                              : sea.withValues(alpha: .10))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _pageIcon(i),
                            size: 20,
                            color: _tab == i
                                ? (_isAtmosphericScene
                                    ? const Color(0xffffd166)
                                    : sea)
                                : _mutedTextColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            pages[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  _tab == i ? FontWeight.w800 : FontWeight.w600,
                              color: _tab == i
                                  ? (_isAtmosphericScene
                                      ? const Color(0xffffd166)
                                      : sea)
                                  : _textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: 30 * i),
                        duration: 300.ms,
                      ),
                ),
                const SizedBox(height: 20),
                _sideHeading('SAVED PLACES'),
                ..._favorites.map(
                  (p) => HoverCard(
                    margin: const EdgeInsets.only(bottom: 6),
                    borderRadius: 12,
                    decoration: _cardGlassDecoration,
                    onTap: () => _choose(p),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.star_rounded,
                        color: Color(0xffd0a349),
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                      subtitle: Text(
                        p.country,
                        style: TextStyle(fontSize: 10, color: _mutedTextColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _content()),
        ],
      );

  Widget _searchBox() => Column(
        children: [
          TextField(
            controller: _searchCtl,
            onChanged: _onSearch,
            onTap: () => setState(() => _searching = true),
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: 'Search a city...',
              hintStyle: TextStyle(color: _mutedTextColor),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
              ),
              filled: true,
              fillColor: _isAtmosphericScene
                  ? Colors.white.withValues(alpha: 0.18)
                  : cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          if (_searching && _results.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: _isAtmosphericScene
                    ? const Color(0xff1b2838)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: _results
                    .map(
                      (p) => ListTile(
                        dense: true,
                        title: Text(
                          p.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                          ),
                        ),
                        subtitle: Text(
                          p.country,
                          style: TextStyle(color: _mutedTextColor),
                        ),
                        onTap: () => _choose(p),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      );

  Widget _content() {
    if (_loading && _weather == null) {
      return Center(
        child: CircularProgressIndicator(
          color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
          strokeWidth: 3,
        ),
      );
    }
    if (_weather == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 54, color: _mutedTextColor)
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Weather data is unavailable.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _mutedTextColor, fontSize: 15),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                  foregroundColor: _isAtmosphericScene ? ink : Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, box) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          box.maxWidth > 700 ? 38 : 18,
          box.maxWidth > 700 ? 26 : 16,
          box.maxWidth > 700 ? 38 : 18,
          36,
        ),
        child: _tab == 0
            ? _dashboard(box.maxWidth)
            : _tab == 1
                ? _mapPage()
                : _tab == 2
                    ? _hourlyPage()
                    : _tab == 3
                        ? _weeklyPage()
                        : _tab == 4
                            ? _windPage()
                            : _tab == 5
                                ? _airPage()
                                : _tab == 6
                                    ? _locationsPage()
                                    : _tab == 7
                                        ? _comparePage()
                                        : _tab == 8
                                            ? _aboutPage()
                                            : _settingsPage(),
      ),
    );
  }

  Widget _dashboard(double width) {
    final w = _weather;
    if (w == null) return const SizedBox.shrink();
    final wide = width > 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(w, wide),
        const SizedBox(height: 24),
        _sectionTitle(
          'The next 24 hours',
          'A closer look at what’s ahead',
          onTap: () => setState(() => _tab = 2),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 14),
        _hourStrip(w).animate().fadeIn(delay: 100.ms, duration: 450.ms),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: wide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: wide ? 1.65 : 1.35,
          children: [
            _metric(
              'FEELS LIKE',
              _temp(w.feels),
              Icons.thermostat_rounded,
              'in the shade',
              0,
            ),
            _metric(
              'WIND',
              '${w.wind.round()} km/h',
              Icons.air_rounded,
              '${_compass(w.bearing)} · gusts ${w.gust.round()}',
              1,
            ),
            _metric(
              'HUMIDITY',
              '${w.humidity}%',
              Icons.water_drop_outlined,
              '${w.rain.toStringAsFixed(1)} mm precipitation',
              2,
            ),
            _metric(
              'UV INDEX',
              w.uv.toStringAsFixed(1),
              Icons.wb_sunny_outlined,
              '${_uvLabel(w.uv)} · pressure ${w.pressure.round()} hPa',
              3,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle(
          'This week',
          'Seven-day outlook',
          onTap: () => setState(() => _tab = 3),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 14),
        _weekPreview(w),
        const SizedBox(height: 24),
        _sectionTitle(
          'Air quality',
          'Live atmospheric readings',
          onTap: () => setState(() => _tab = 5),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 14),
        _airSummary(),
      ],
    );
  }

  /// Calculates atmospheric color palette based on BackgroundScene (Sunrise, Sunset, Moonlight, Day)
  List<Color> _skyColors(BackgroundScene scene, int code) {
    final storm = code >= 95;
    final rain = (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || storm;
    final snow = (code >= 71 && code <= 77) || code == 85 || code == 86;

    if (storm) {
      return [
        const Color(0xff1f2833),
        const Color(0xff394956),
        const Color(0xff526472),
      ];
    }
    if (rain) {
      return [
        const Color(0xff2c3e50),
        const Color(0xff53717f),
        const Color(0xff7895a0),
      ];
    }
    if (snow) {
      return [
        const Color(0xff4b6584),
        const Color(0xff778ca3),
        const Color(0xffd1d8e0),
      ];
    }

    return switch (scene) {
      BackgroundScene.sunrise => [
          const Color(0xff3f2b47),
          const Color(0xffb84a5f),
          const Color(0xffe88358),
          const Color(0xfffcd077),
        ],
      BackgroundScene.sunset => [
          const Color(0xff221b38),
          const Color(0xff572652),
          const Color(0xffab4457),
          const Color(0xffe07e53),
        ],
      BackgroundScene.moonlight => [
          const Color(0xff0d1b2a),
          const Color(0xff1b263b),
          const Color(0xff415a77),
          const Color(0xff778da9),
        ],
    };
  }

  Widget _hero(WeatherData w, bool wide) {
    final scene = _activeScene;
    final code = w.code;
    final storm = code >= 95,
        rain =
            (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || storm,
        cloudy = code == 2 || code == 3 || code == 45 || code == 48;

    final dt = DateFormat('EEEE, d MMMM · HH:mm').format(w.localTime);
    final sunrise = _clock(w.sunrise);
    final sunset = _clock(w.sunset);

    final sky = _skyColors(scene, code);

    final heroWidth = wide ? 900.0 : 400.0;
    final heroHeight = wide ? 335.0 : 365.0;
    final dx = _heroHovered
        ? ((_heroMouse.dx / heroWidth) - 0.5).clamp(-0.5, 0.5)
        : 0.0;
    final dy = _heroHovered
        ? ((_heroMouse.dy / heroHeight) - 0.5).clamp(-0.5, 0.5)
        : 0.0;

    return MouseRegion(
      onEnter: (e) => setState(() {
        _heroHovered = true;
        _heroMouse = e.localPosition;
      }),
      onHover: (e) => setState(() => _heroMouse = e.localPosition),
      onExit: (_) => setState(() {
        _heroHovered = false;
        _heroMouse = Offset.zero;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        height: wide ? 340 : 375,
        width: double.infinity,
        padding: EdgeInsets.all(wide ? 34 : 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: sky,
          ),
          boxShadow: [
            BoxShadow(
              color: sky.first.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 14),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (scene == BackgroundScene.moonlight)
              ...List.generate(
                24,
                (i) => Positioned(
                  left: ((i * 47.0) + (dx * 15)) % (wide ? 850 : 340),
                  top: ((i * 31.0) + (dy * 12)) % 220,
                  child: Container(
                    width: (i % 3 == 0) ? 3.0 : 2.0,
                    height: (i % 3 == 0) ? 3.0 : 2.0,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ).animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  ).fadeIn(
                    duration: Duration(milliseconds: 800 + (i * 120)),
                  ),
                ),
              ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              right: (wide ? 115.0 : 20.0) - (dx * 28),
              top: (scene == BackgroundScene.moonlight ? 36.0 : 25.0) - (dy * 20),
              child: _celestialBody(scene),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              left: (wide ? 320.0 : 170.0) + (dx * 22),
              top: (wide ? 125.0 : 154.0) + (dy * 14),
              child: _cloud(94, cloudy ? .58 : .30),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              right: (wide ? 30.0 : 10.0) + (dx * 35),
              top: 175.0 + (dy * 22),
              child: _cloud(135, cloudy ? .72 : .42),
            ),

            if (rain)
              ...List.generate(
                32,
                (i) => Positioned(
                  left: (i * 28.0) % (wide ? 850 : 340),
                  top: (30 + (i * 37.0)) % 260,
                  child: Transform.rotate(
                    angle: -.25,
                    child: Container(
                      width: 1.8,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              left: dx * 6,
              top: dy * 6,
              right: -dx * 6,
              bottom: -dy * 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _place.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      _tag(scene.displayName.toUpperCase(), Colors.white),
                      const SizedBox(width: 6),
                      PopupMenuButton<BackgroundMode>(
                        tooltip: 'Atmospheric scene',
                        icon: const Icon(
                          Icons.wb_twilight_rounded,
                          color: Colors.white,
                        ),
                        onSelected: (mode) => setState(() {
                          _bgMode = mode;
                          _persist();
                        }),
                        itemBuilder: (_) => BackgroundMode.values
                            .map(
                              (m) => PopupMenuItem(
                                value: m,
                                child: Row(
                                  children: [
                                    Icon(
                                      _sceneModeIcon(m),
                                      size: 18,
                                      color: _bgMode == m ? sea : ink,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      m.label,
                                      style: TextStyle(
                                        fontWeight: _bgMode == m
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _temp(w.temp),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: wide ? 82 : 74,
                                fontWeight: FontWeight.w300,
                                height: 1,
                                letterSpacing: -5,
                                shadows: const [
                                  Shadow(color: Colors.black26, blurRadius: 12),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            w.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Feels like ${_temp(w.feels)}  ·  H:${_temp(w.high)}  L:${_temp(w.low)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (wide)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              dt,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sunrise $sunrise    Sunset $sunset',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (!wide)
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dt,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '↑ $sunrise  ·  ↓ $sunset',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.05);
  }

  IconData _sceneModeIcon(BackgroundMode m) => switch (m) {
        BackgroundMode.automatic => Icons.auto_awesome_rounded,
        BackgroundMode.sunrise => Icons.wb_twilight_rounded,
        BackgroundMode.sunset => Icons.wb_sunny_rounded,
        BackgroundMode.moonlight => Icons.nightlight_round,
      };

  Widget _celestialBody(BackgroundScene scene) {
    return switch (scene) {
      BackgroundScene.sunrise => Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xfffff4cc), Color(0xffffba66)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffffd166).withValues(alpha: 0.65),
                blurRadius: 64,
                spreadRadius: 28,
              ),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.06, 1.06),
            duration: 2500.ms,
            curve: Curves.easeInOut,
          ),
      BackgroundScene.sunset => Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xffffe6b3), Color(0xffff6b6b)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffff85a2).withValues(alpha: 0.60),
                blurRadius: 64,
                spreadRadius: 26,
              ),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.05, 1.05),
            duration: 2200.ms,
            curve: Curves.easeInOut,
          ),
      BackgroundScene.moonlight => Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xfff8f9fa), Color(0xffd8e2dc)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffe8efff).withValues(alpha: 0.65),
                blurRadius: 58,
                spreadRadius: 24,
              ),
            ],
          ),
          child: const Icon(
            Icons.nightlight_round,
            color: Color(0xff748899),
            size: 64,
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.04, 1.04),
            duration: 2800.ms,
            curve: Curves.easeInOut,
          ),
    };
  }

  Widget _cloud(double size, double opacity) => Icon(
        Icons.cloud_rounded,
        size: size,
        color: Colors.white.withValues(alpha: opacity),
      );

  Widget _tag(String s, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(
          s,
          style: TextStyle(
            color: c,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _sectionTitle(String title, String sub, {VoidCallback? onTap}) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                    letterSpacing: -.5,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor:
                    _isAtmosphericScene ? const Color(0xffffd166) : sea,
              ),
              child: const Text(
                'View all',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      );

  Widget _hourStrip(WeatherData w) => Container(
        height: 145,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: _cardGlassDecoration,
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemCount: 24,
          separatorBuilder: (context, index) => VerticalDivider(
            width: 1,
            color: _isAtmosphericScene
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xffedf0f1),
          ),
          itemBuilder: (c, i) {
            final h = w.hourly;
            final temps = (h['temperature_2m'] as List? ?? []);
            final codes = (h['weather_code'] as List? ?? []);
            final times = (h['time'] as List? ?? []);
            final probs = (h['precipitation_probability'] as List? ?? []);
            final winds = (h['wind_speed_10m'] as List? ?? []);
            final start = (times.indexWhere(
              (x) =>
                  DateTime.tryParse('$x')?.isAfter(
                    w.localTime.subtract(const Duration(hours: 1)),
                  ) ??
                  false,
            )).clamp(0, math.max(temps.length - 1, 0)).toInt();
            final n = start + i;
            if (n >= temps.length) return const SizedBox.shrink();
            final time = DateTime.tryParse('${times[n]}') ?? w.localTime;
            return HoverCard(
              enableTilt: false,
              borderRadius: 14,
              decoration: const BoxDecoration(color: Colors.transparent),
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      i == 0 ? 'Now' : DateFormat('ha').format(time),
                      style: TextStyle(
                        color: _mutedTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      weatherIcon(
                        n < codes.length ? (codes[n] as num).toInt() : 0,
                      ),
                      size: 22,
                      color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _temp(temps[n] as num),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textColor,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${n < probs.length ? probs[n] : 0}% · ${(n < winds.length ? (winds[n] as num).round() : 0)}km/h',
                        style: TextStyle(
                          fontSize: 9,
                          color: _mutedTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _metric(
    String label,
    String value,
    IconData icon,
    String foot,
    int index,
  ) =>
      HoverCard(
        depth: 1.2,
        decoration: _cardGlassDecoration,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w900,
                          color: _mutedTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Text(
                foot,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: _mutedTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(
            delay: Duration(milliseconds: 80 * index),
            duration: 400.ms,
          ).scale(begin: const Offset(0.95, 0.95));

  String _compass(int b) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((b + 22.5) / 45).floor() % 8];
  }

  String _uvLabel(double n) => n < 3
      ? 'Low'
      : n < 6
          ? 'Moderate'
          : n < 8
              ? 'High'
              : n < 11
                  ? 'Very high'
                  : 'Extreme';

  Widget _weekPreview(WeatherData w) => Column(
        children: List.generate(
          7,
          (i) => _dayRow(w, i, compact: true).animate().fadeIn(
                delay: Duration(milliseconds: 50 * i),
                duration: 350.ms,
              ),
        ),
      );

  Widget _dayRow(WeatherData w, int i, {bool compact = false}) {
    final d = w.daily;
    final times = (d['time'] as List? ?? []),
        codes = (d['weather_code'] as List? ?? []),
        maxs = (d['temperature_2m_max'] as List? ?? []),
        mins = (d['temperature_2m_min'] as List? ?? []),
        rains = (d['precipitation_probability_max'] as List? ?? []),
        winds = (d['wind_speed_10m_max'] as List? ?? []),
        uvs = (d['uv_index_max'] as List? ?? []);
    if (i >= times.length) return const SizedBox.shrink();
    final date = DateTime.tryParse('${times[i]}') ?? DateTime.now();
    return HoverCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(
        horizontal: 18,
        vertical: compact ? 12 : 16,
      ),
      decoration: _cardGlassDecoration,
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              i == 0 ? 'Today' : DateFormat('EEE, d MMM').format(date),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: _textColor,
              ),
            ),
          ),
          Icon(
            weatherIcon((codes[i] as num).toInt()),
            color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
            size: 22,
          ),
          const SizedBox(width: 12),
          if (!compact)
            Expanded(
              child: Text(
                weatherText((codes[i] as num).toInt()),
                style: TextStyle(
                  color: _mutedTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (compact) const Spacer(),
          Text(
            '${rains.isNotEmpty ? rains[i] : 0}%',
            style: TextStyle(
              color: _mutedTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            '${(mins[i] as num).round()}°',
            style: TextStyle(
              color: _mutedTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text(
              '${(maxs[i] as num).round()}°',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _textColor,
                fontSize: 14,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 18),
            Text(
              '${(winds[i] as num).round()} km/h',
              style: TextStyle(fontSize: 12, color: _mutedTextColor),
            ),
            const SizedBox(width: 18),
            Text(
              'UV ${(uvs[i] as num).toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, color: _mutedTextColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hourlyPage() {
    final w = _weather;
    if (w == null) return const SizedBox.shrink();
    final times = w.hourly['time'] as List? ?? [];
    final temps = w.hourly['temperature_2m'] as List? ?? [];
    final start = times
        .indexWhere(
          (x) =>
              DateTime.tryParse('$x')?.isAfter(
                w.localTime.subtract(const Duration(hours: 1)),
              ) ??
              false,
        )
        .clamp(0, math.max(times.length - 1, 0))
        .toInt();
    final pts = <FlSpot>[];
    for (var i = 0; i < 24 && start + i < temps.length; i++) {
      pts.add(FlSpot(i.toDouble(), (temps[start + i] as num).toDouble()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Hourly forecast', 'The next 24 hours in ${_place.name}')
            .animate()
            .fadeIn(),
        const SizedBox(height: 18),
        _chart(pts, 'TEMPERATURE', height: 220).animate().fadeIn(duration: 450.ms),
        const SizedBox(height: 20),
        _hourStrip(w).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 20),
        ...List.generate(
          24,
          (i) => _hourRow(w, start + i, i).animate().fadeIn(
                delay: Duration(milliseconds: 30 * i),
                duration: 300.ms,
              ),
        ),
      ],
    );
  }

  Widget _hourRow(WeatherData w, int n, int i) {
    final h = w.hourly,
        times = h['time'] as List? ?? [],
        temps = h['temperature_2m'] as List? ?? [],
        codes = h['weather_code'] as List? ?? [],
        probs = h['precipitation_probability'] as List? ?? [],
        rains = h['precipitation'] as List? ?? [],
        winds = h['wind_speed_10m'] as List? ?? [];
    if (n >= times.length) return const SizedBox.shrink();
    final t = DateTime.tryParse('${times[n]}') ?? w.localTime;
    return HoverCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: _cardGlassDecoration,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              i == 0 ? 'Now' : DateFormat('ha').format(t),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: _textColor,
              ),
            ),
          ),
          Icon(
            weatherIcon((codes[n] as num).toInt()),
            color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              weatherText((codes[n] as num).toInt()),
              style: TextStyle(
                color: _mutedTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${probs[n]}%',
            style: TextStyle(
              color: _mutedTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${(rains[n] as num).toStringAsFixed(1)} mm',
            style: TextStyle(color: _mutedTextColor, fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            '${(winds[n] as num).round()} km/h',
            style: TextStyle(color: _mutedTextColor, fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            _temp(temps[n] as num),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: _textColor,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyPage() {
    final w = _weather;
    if (w == null) return const SizedBox.shrink();
    final maxs = w.daily['temperature_2m_max'] as List? ?? [];
    final pts = List.generate(
      maxs.length,
      (i) => FlSpot(i.toDouble(), (maxs[i] as num).toDouble()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('7-day forecast', 'A week of weather, at a glance')
            .animate()
            .fadeIn(),
        const SizedBox(height: 18),
        _chart(pts, 'DAILY HIGH', height: 210).animate().fadeIn(duration: 450.ms),
        const SizedBox(height: 18),
        ...List.generate(
          7,
          (i) => _dayRow(w, i).animate().fadeIn(
                delay: Duration(milliseconds: 50 * i),
                duration: 350.ms,
              ),
        ),
      ],
    );
  }

  Widget _chart(List<FlSpot> points, String label, {double height = 200}) =>
      HoverCard(
        enableTilt: false,
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 8),
        decoration: _cardGlassDecoration,
        child: SizedBox(
          height: height + 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 1.3,
                  color: _mutedTextColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: math.max(points.length - 1, 1).toDouble(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: _isAtmosphericScene
                            ? Colors.white.withValues(alpha: 0.15)
                            : const Color(0xffedf0f1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: math.max(
                            (points.length / 6).floorToDouble(),
                            1,
                          ),
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              '${value.toInt()}',
                              style: TextStyle(
                                color: _mutedTextColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: points,
                        isCurved: true,
                        color: _isAtmosphericScene
                            ? const Color(0xffffd166)
                            : sea,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2.5,
                            strokeColor: _isAtmosphericScene
                                ? const Color(0xffffd166)
                                : sea,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: (_isAtmosphericScene
                                  ? const Color(0xffffd166)
                                  : sea)
                              .withValues(alpha: .14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _windPage() {
    final w = _weather;
    if (w == null) return const SizedBox.shrink();
    final speeds = w.hourly['wind_speed_10m'] as List? ?? [],
        pts = List.generate(
          math.min(24, speeds.length),
          (i) => FlSpot(i.toDouble(), (speeds[i] as num).toDouble()),
        );
    final beau = (math.sqrt(w.wind / 3.6) * 1.62).round().clamp(0, 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Wind intelligence', 'Wind conditions in ${_place.name}')
            .animate()
            .fadeIn(),
        const SizedBox(height: 18),
        HoverCard(
          padding: const EdgeInsets.all(28),
          decoration: _cardGlassDecoration,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                AnimatedRotation(
                  turns: w.bearing / 360.0,
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    Icons.navigation_rounded,
                    size: 92,
                    color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                  ),
                ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                const SizedBox(height: 10),
                Text(
                  '${w.wind.round()} km/h',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
                Text(
                  '${_compass(w.bearing)} · ${w.bearing}° bearing',
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _smallStat('GUSTS', '${w.gust.round()} km/h'),
                    _smallStat('BEAUFORT', '$beau / 12'),
                    _smallStat('DIRECTION', _compass(w.bearing)),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 450.ms),
        const SizedBox(height: 20),
        _chart(pts, 'HOURLY WIND SPEED · KM/H', height: 210),
        const SizedBox(height: 20),
        _sectionTitle('Hourly wind', 'Forecast wind speed'),
        const SizedBox(height: 14),
        _hourStrip(w),
      ],
    );
  }

  Widget _smallStat(String label, String val) => Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: _mutedTextColor,
              fontSize: 9.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            val,
            style: TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );

  Widget _airSummary() {
    if (_airLoading) {
      return HoverCard(
        padding: const EdgeInsets.all(24),
        decoration: _cardGlassDecoration,
        child: const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
    }
    if (_air == null) {
      return HoverCard(
        padding: const EdgeInsets.all(20),
        decoration: _cardGlassDecoration,
        child: Text(
          'Air quality readings are currently unavailable for this location.',
          style: TextStyle(color: _mutedTextColor, fontWeight: FontWeight.w500),
        ),
      );
    }
    final a = _air!;
    final aqi = (a['european_aqi'] as num?)?.round();
    final color = aqi == null
        ? _mutedTextColor
        : aqi < 21
            ? const Color(0xff3e9b75)
            : aqi < 41
                ? const Color(0xff98a847)
                : aqi < 61
                    ? const Color(0xffdc9e3d)
                    : const Color(0xffcc675a);

    return HoverCard(
      padding: const EdgeInsets.all(20),
      decoration: _cardGlassDecoration,
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${aqi ?? '—'}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aqi == null ? 'AQI unavailable' : _aqiLabel(aqi),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'European AQI · Open-Meteo Air Quality',
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'PM₂.₅  ${((a['pm2_5'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _textColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _aqiLabel(int n) => n <= 20
      ? 'Good'
      : n <= 40
          ? 'Fair'
          : n <= 60
              ? 'Moderate'
              : n <= 80
                  ? 'Poor'
                  : n <= 100
                      ? 'Very poor'
                      : 'Extremely poor';

  Widget _airPage() {
    final a = _air;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Air quality',
          'Measured air conditions · ${_place.name}',
        ).animate().fadeIn(),
        const SizedBox(height: 18),
        _airSummary(),
        if (a != null) ...[
          const SizedBox(height: 22),
          Text(
            'POLLUTANTS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: _mutedTextColor,
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 12),
          ...[
            _pollutant('PM2.5', 'pm2_5', 'μg/m³', 0),
            _pollutant('PM10', 'pm10', 'μg/m³', 1),
            _pollutant('Carbon monoxide', 'carbon_monoxide', 'μg/m³', 2),
            _pollutant('Nitrogen dioxide', 'nitrogen_dioxide', 'μg/m³', 3),
            _pollutant('Ozone', 'ozone', 'μg/m³', 4),
            _pollutant('Sulphur dioxide', 'sulphur_dioxide', 'μg/m³', 5),
          ],
          const SizedBox(height: 14),
          Text(
            'Readings are supplied by Open-Meteo. AQI uses the European scale (0–100+). Forecast model estimates may not reflect local roadside conditions.',
            style: TextStyle(color: _mutedTextColor, fontSize: 11.5),
          ),
        ],
      ],
    );
  }

  Widget _pollutant(String name, String key, String unit, int i) {
    final n = (_air?[key] as num?)?.toDouble();
    return HoverCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: _cardGlassDecoration,
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontWeight: FontWeight.w800, color: _textColor),
            ),
          ),
          Text(
            n == null ? 'Unavailable' : '${n.toStringAsFixed(1)} $unit',
            style: TextStyle(
              color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 50 * i),
          duration: 350.ms,
        );
  }

  Widget _mapPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Weather map', 'Explore ${_place.name} and the world')
              .animate()
              .fadeIn(),
          const SizedBox(height: 16),
          HoverCard(
            enableTilt: false,
            borderRadius: 24,
            decoration: _cardGlassDecoration,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .62,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_place.lat, _place.lon),
                  initialZoom: 7,
                  onTap: (tap, point) => _inspect(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.aether.weather',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_place.lat, _place.lon),
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          color: sea,
                          size: 46,
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© OpenStreetMap contributors',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Map data © OpenStreetMap contributors'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 16),
          HoverCard(
            padding: const EdgeInsets.all(18),
            decoration: _cardGlassDecoration,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Map tiles show geographic data only. Live weather overlays require a licensed tile source and are not available in this build.',
                    style: TextStyle(color: _mutedTextColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  void _inspect(LatLng point) async {
    try {
      final r = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': point.latitude,
          'longitude': point.longitude,
          'current': 'temperature_2m,weather_code',
          'timezone': 'auto',
        },
      );
      final cur = r.data['current'];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${point.latitude.toStringAsFixed(2)}, ${point.longitude.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(cur['temperature_2m'] as num).round()}° · ${weatherText(cur['weather_code'])}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: sea,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _choose(
                      Place(
                        'Map location',
                        '${point.latitude.toStringAsFixed(2)}, ${point.longitude.toStringAsFixed(2)}',
                        point.latitude,
                        point.longitude,
                      ),
                    );
                  },
                  child: const Text(
                    'Use this location',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  Widget _locationsPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Global locations',
            'Search and save places around the world',
          ).animate().fadeIn(),
          const SizedBox(height: 16),
          _searchBox(),
          const SizedBox(height: 22),
          _sectionTitle('Recent searches', 'Your recently viewed locations'),
          const SizedBox(height: 12),
          if (_recent.isEmpty)
            Text(
              'Locations you view will appear here.',
              style: TextStyle(color: _mutedTextColor),
            ),
          ..._recent.map((p) => _placeRow(p)),
          const SizedBox(height: 22),
          _sectionTitle('Favorites', 'Saved for quick access'),
          const SizedBox(height: 12),
          if (_favorites.isEmpty)
            Text(
              'Tap the star next to a city to save it.',
              style: TextStyle(color: _mutedTextColor),
            ),
          ..._favorites.map((p) => _placeRow(p, favorite: true)),
        ],
      );

  Widget _placeRow(Place p, {bool favorite = false}) => HoverCard(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: _cardGlassDecoration,
        child: ListTile(
          leading: Icon(
            Icons.location_on_outlined,
            color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
          ),
          title: Text(
            p.name,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
          subtitle: Text(
            p.country,
            style: TextStyle(color: _mutedTextColor),
          ),
          trailing: IconButton(
            icon: Icon(
              favorite ? Icons.star : Icons.star_border,
              color: const Color(0xffd0a349),
            ),
            onPressed: () async {
              setState(
                () => favorite
                    ? _favorites.removeWhere((x) => x.label == p.label)
                    : _favorites.add(p),
              );
              await _persist();
            },
          ),
          onTap: () => _choose(p),
        ),
      );

  Widget _comparePage() {
    final places = [
      _place,
      ..._favorites.where((p) => p.label != _place.label),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Weather comparison',
          'Compare conditions across saved locations',
        ).animate().fadeIn(),
        const SizedBox(height: 18),
        ...places.map(
          (p) => FutureBuilder<Response<dynamic>>(
            future: _dio.get(
              'https://api.open-meteo.com/v1/forecast',
              queryParameters: {
                'latitude': p.lat,
                'longitude': p.lon,
                'timezone': 'auto',
                'current': 'temperature_2m,weather_code,wind_speed_10m',
              },
            ),
            builder: (c, s) {
              if (!s.hasData) {
                return HoverCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(24),
                  decoration: _cardGlassDecoration,
                  child: const SizedBox(
                    height: 40,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final x = s.data!.data['current'];
              return HoverCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: _cardGlassDecoration,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _textColor,
                        ),
                      ),
                    ),
                    Icon(
                      weatherIcon(x['weather_code']),
                      color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${(x['temperature_2m'] as num).round()}°',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Text(
                      '${(x['wind_speed_10m'] as num).round()} km/h',
                      style: TextStyle(
                        fontSize: 12,
                        color: _mutedTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Add a favorite from Global locations to include another city.',
          style: TextStyle(color: _mutedTextColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _aboutPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Weather, with a little more atmosphere',
            'AETHER WEATHER',
          ).animate().fadeIn(),
          const SizedBox(height: 18),
          HoverCard(
            padding: const EdgeInsets.all(26),
            decoration: _cardGlassDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A calmer way to read the sky.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Aether brings current conditions, forecasts and atmospheric context together in one considered view. The sky preview follows the selected location’s local sunrise and sunset; manual previews change the artwork only.',
                  style: TextStyle(
                    color: _mutedTextColor,
                    height: 1.7,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'DATA SOURCES',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Weather forecast · Open-Meteo\nAir quality · Open-Meteo\nMap tiles · © OpenStreetMap contributors',
                  style: TextStyle(
                    color: _textColor,
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms),
        ],
      );

  Widget _settingsPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Settings', 'Make Aether feel like yours')
              .animate()
              .fadeIn(),
          const SizedBox(height: 18),
          HoverCard(
            padding: EdgeInsets.zero,
            decoration: _cardGlassDecoration,
            child: Column(
              children: [
                SwitchListTile(
                  activeTrackColor: sea,
                  title: Text(
                    'Temperature in Fahrenheit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textColor,
                    ),
                  ),
                  subtitle: Text(
                    'Turn off for Celsius',
                    style: TextStyle(color: _mutedTextColor),
                  ),
                  value: _fahrenheit,
                  onChanged: (v) async {
                    setState(() => _fahrenheit = v);
                    await _persist();
                  },
                ),
                Divider(
                  height: 1,
                  color: _isAtmosphericScene
                      ? Colors.white.withValues(alpha: 0.18)
                      : const Color(0xffedf0f1),
                ),
                ListTile(
                  title: Text(
                    'Atmospheric Scene Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textColor,
                    ),
                  ),
                  subtitle: Text(
                    _bgMode.label,
                    style: TextStyle(color: _mutedTextColor),
                  ),
                  trailing: DropdownButton<BackgroundMode>(
                    value: _bgMode,
                    dropdownColor: _isAtmosphericScene
                        ? const Color(0xff1b2838)
                        : Colors.white,
                    underline: const SizedBox.shrink(),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                    ),
                    onChanged: (mode) {
                      if (mode != null) {
                        setState(() => _bgMode = mode);
                        _persist();
                      }
                    },
                    items: BackgroundMode.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _textColor,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Divider(
                  height: 1,
                  color: _isAtmosphericScene
                      ? Colors.white.withValues(alpha: 0.18)
                      : const Color(0xffedf0f1),
                ),
                ListTile(
                  title: Text(
                    'Wind speed unit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textColor,
                    ),
                  ),
                  subtitle: Text(
                    'Kilometres per hour (km/h)',
                    style: TextStyle(color: _mutedTextColor),
                  ),
                  trailing: Icon(Icons.chevron_right, color: _mutedTextColor),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 22),
          _sectionTitle(
            'Current location',
            '${_place.lat.toStringAsFixed(3)}, ${_place.lon.toStringAsFixed(3)} · ${_weather?.timezone ?? '—'}',
          ),
          const SizedBox(height: 12),
          HoverCard(
            decoration: _cardGlassDecoration,
            child: ListTile(
              leading: Icon(
                Icons.location_on,
                color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                size: 26,
              ),
              title: Text(
                _place.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
              subtitle: Text(
                'Weather updated ${_weather == null ? '—' : DateFormat('HH:mm').format(_weather!.localTime)} local time',
                style: TextStyle(color: _mutedTextColor),
              ),
              trailing: IconButton(
                onPressed: _load,
                icon: Icon(
                  Icons.refresh,
                  color: _isAtmosphericScene ? const Color(0xffffd166) : sea,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _sideHeading(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 9.5,
            letterSpacing: 1.5,
            color: _mutedTextColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _errorBanner() => Container(
        color: const Color(0xfffff1ea),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Color(0xffbd6b45)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff8a3c1b),
                ),
              ),
            ),
            TextButton(
              onPressed: _load,
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
}
