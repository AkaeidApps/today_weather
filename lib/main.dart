import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/atmos_theme.dart';

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
      _fahrenheit = false,
      _previewNight = false,
      _manualPreview = false;
  String? _error;
  int _tab = 0;
  List<Place> _recent = [];
  List<Place> _favorites = [];
  Timer? _searchTimer;
  List<Place> _results = [];
  bool _searching = false;
  final _searchCtl = TextEditingController();
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
    await p.setString('place', _encodePlace(_place));
    await p.setStringList('favorites', _favorites.map(_encodePlace).toList());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _error = null;
    try {
      final url = 'https://api.open-meteo.com/v1/forecast';
      final r = await _dio.get(
        url,
        queryParameters: {
          'latitude': _place.lat,
          'longitude': _place.lon,
          'timezone': 'auto',
          'forecast_days': 7,
          'forecast_hours': 48,
          'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,visibility',
          'hourly': 'temperature_2m,precipitation_probability,precipitation,weather_code,wind_speed_10m,relative_humidity_2m',
          'daily': 'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,wind_speed_10m_max,uv_index_max',
        },
      );
      if (!mounted) return;
      setState(() => _weather = WeatherData(Map<String, dynamic>.from(r.data)));
      _loadAir();
    } catch (e) {
      if (mounted)
        setState(
          () => _error = 'Weather data is unavailable. Check your connection and try again.',
        );
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
          'current': 'european_aqi,us_aqi,pm2_5,pm10,carbon_monoxide,nitrogen_dioxide,ozone,sulphur_dioxide',
        },
      );
      if (mounted)
        setState(
          () => _air = Map<String, dynamic>.from(r.data['current'] ?? {}),
        );
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
      if (!await Geolocator.isLocationServiceEnabled())
        throw Exception('Enable location services to use your location.');
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied)
        p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever)
        throw Exception(
          'Location permission was not granted. Search for a city instead.',
        );
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
        if (x != null)
          here = Place(
            '${x['name']}',
            '${x['country'] ?? ''}',
            pos.latitude,
            pos.longitude,
            '${x['timezone'] ?? 'auto'}',
          );
      } catch (_) {}
      await _choose(here);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    }
  }

  String _temp(num n) =>
      '${_fahrenheit ? (n * 9 / 5 + 32).round() : n.round()}°';
  String _clock(String value) =>
      value.length >= 16 ? value.substring(11, 16) : '—';
  bool get _night => _manualPreview
      ? _previewNight
      : (_weather == null ? false : !_weather!.isDay(_place));
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 850;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(wide),
            if (_error != null) _errorBanner(),
            Expanded(child: wide ? _desktopBody() : _mobileBody()),
            if (!wide) _bottomNav(),
          ],
        ),
      ),
      floatingActionButton: wide
          ? null
          : FloatingActionButton.small(
              onPressed: _gps,
              backgroundColor: ink,
              foregroundColor: Colors.white,
              child: const Icon(Icons.my_location_rounded),
            ),
    );
  }

  Widget _header(bool wide) => Container(
    color: cream,
    padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 18, vertical: 13),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.air_rounded, color: Colors.white, size: 23),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATMOS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 2.0,
                color: ink,
              ),
            ),
            Text(
              'WEATHER',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 9,
                letterSpacing: 2.8,
                color: muted,
              ),
            ),
          ],
        ),
        if (wide) ...[
          const SizedBox(width: 35),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(pages.length, (i) => _navLabel(i)),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        IconButton(
          tooltip: 'Use my location',
          onPressed: _gps,
          icon: const Icon(Icons.my_location_rounded, color: ink),
        ),
        if (wide)
          IconButton(
            tooltip: 'Temperature units',
            onPressed: () => setState(() {
              _fahrenheit = !_fahrenheit;
              _persist();
            }),
            icon: Text(
              _fahrenheit ? '°F' : '°C',
              style: const TextStyle(fontWeight: FontWeight.bold, color: ink),
            ),
          ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => setState(() => _tab = 9),
          icon: const Icon(Icons.tune_rounded, color: ink),
        ),
      ],
    ),
  );
  Widget _navLabel(int i) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: TextButton(
      onPressed: () => setState(() => _tab = i),
      style: TextButton.styleFrom(foregroundColor: _tab == i ? sea : muted),
      child: Text(
        pages[i],
        style: TextStyle(
          fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    ),
  );
  Widget _bottomNav() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xffe9edef))),
    ),
    child: NavigationBar(
      height: 66,
      selectedIndex: _tab < 5 ? _tab : 0,
      onDestinationSelected: (i) => setState(() => _tab = i),
      backgroundColor: Colors.white,
      indicatorColor: sea.withOpacity(.12),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.wb_sunny_outlined),
          selectedIcon: Icon(Icons.wb_sunny_rounded),
          label: 'Today',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Map',
        ),
        NavigationDestination(icon: Icon(Icons.schedule), label: 'Hourly'),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: '7 day',
        ),
        NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
      ],
    ),
  );
  Widget _mobileBody() => _tab == 4 ? _moreMenu() : _content();
  Widget _moreMenu() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Explore Aether',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink),
      ),
      const SizedBox(height: 18),
      ...List.generate(pages.length - 5, (i) {
        final k = i + 5;
        return ListTile(
          leading: Icon(_pageIcon(k), color: sea),
          title: Text(pages[k]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => _tab = k),
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
      Container(
        width: 255,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xffe9edef))),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _searchBox(),
            const SizedBox(height: 24),
            _sideHeading('YOUR WEATHER'),
            ...List.generate(
              pages.length,
              (i) => ListTile(
                dense: true,
                selected: _tab == i,
                selectedTileColor: sea.withOpacity(.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  _pageIcon(i),
                  size: 20,
                  color: _tab == i ? sea : muted,
                ),
                title: Text(
                  pages[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onTap: () => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: 15),
            _sideHeading('SAVED PLACES'),
            ..._favorites.map(
              (p) => ListTile(
                dense: true,
                leading: const Icon(
                  Icons.star_rounded,
                  color: Color(0xffd0a349),
                ),
                title: Text(p.name),
                onTap: () => _choose(p),
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
        decoration: InputDecoration(
          hintText: 'Search a city',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: cream,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
      if (_searching && _results.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: ink.withOpacity(.08), blurRadius: 18)],
          ),
          child: Column(
            children: _results
                .map(
                  (p) => ListTile(
                    dense: true,
                    title: Text(p.name),
                    subtitle: Text(p.country),
                    onTap: () => _choose(p),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );
  Widget _content() {
    if (_loading && _weather == null)
      return const Center(child: CircularProgressIndicator(color: sea));
    if (_weather == null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42, color: muted),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Weather data is unavailable.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    return LayoutBuilder(
      builder: (ctx, box) => SingleChildScrollView(
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
        const SizedBox(height: 22),
        _sectionTitle(
          'The next 24 hours',
          'A closer look at what’s ahead',
          onTap: () => setState(() => _tab = 2),
        ),
        const SizedBox(height: 12),
        _hourStrip(w),
        const SizedBox(height: 22),
        GridView.count(
          crossAxisCount: wide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: wide ? 1.7 : 1.45,
          children: [
            _metric(
              'FEELS LIKE',
              _temp(w.feels),
              Icons.thermostat_rounded,
              'in the shade',
            ),
            _metric(
              'WIND',
              '${w.wind.round()} km/h',
              Icons.air_rounded,
              '${_compass(w.bearing)} · gusts ${w.gust.round()}',
            ),
            _metric(
              'HUMIDITY',
              '${w.humidity}%',
              Icons.water_drop_outlined,
              '${w.rain.toStringAsFixed(1)} mm precipitation',
            ),
            _metric(
              'UV INDEX',
              w.uv.toStringAsFixed(1),
              Icons.wb_sunny_outlined,
              '${_uvLabel(w.uv)} · pressure ${w.pressure.round()} hPa',
            ),
          ],
        ),
        const SizedBox(height: 22),
        _sectionTitle(
          'This week',
          'Seven-day outlook',
          onTap: () => setState(() => _tab = 3),
        ),
        const SizedBox(height: 12),
        _weekPreview(w),
        const SizedBox(height: 22),
        _sectionTitle(
          'Air quality',
          'Live atmospheric readings',
          onTap: () => setState(() => _tab = 5),
        ),
        const SizedBox(height: 12),
        _airSummary(),
      ],
    );
  }

  Widget _hero(WeatherData w, bool wide) {
    final night = _night;
    final code = w.code;
    final storm = code >= 95,
        rain =
            (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || storm,
        snow = code >= 71 && code <= 77 || code == 85 || code == 86,
        cloudy = code == 2 || code == 3 || code == 45 || code == 48;
    final dt = DateFormat('EEEE, d MMMM · HH:mm').format(w.localTime);
    final sunrise = _clock(w.sunrise);
    final sunset = _clock(w.sunset);
    final sky = night
        ? [
            const Color(0xff17283d),
            const Color(0xff263951),
            const Color(0xff48586a),
          ]
        : storm
        ? [
            const Color(0xff394956),
            const Color(0xff526472),
            const Color(0xff75828a),
          ]
        : rain
        ? [
            const Color(0xff53717f),
            const Color(0xff7895a0),
            const Color(0xff9cb2b7),
          ]
        : snow
        ? [
            const Color(0xff8caebd),
            const Color(0xffbfd3d8),
            const Color(0xffe3e7df),
          ]
        : cloudy
        ? [
            const Color(0xff6d9aaa),
            const Color(0xff9cb9bf),
            const Color(0xffc3c8be),
          ]
        : [
            const Color(0xff77c4d8),
            const Color(0xffacd8da),
            const Color(0xffe4d7b3),
          ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      height: wide ? 335 : 365,
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 34 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: sky,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: wide ? 115 : 22,
            top: night ? 42 : 25,
            child: (rain || storm) && !night
                ? const SizedBox(width: 126, height: 126)
                : _celestial(night),
          ),
          Positioned(
            left: wide ? 320 : 180,
            top: wide ? 125 : 154,
            child: _cloud(90, cloudy ? .52 : .25),
          ),
          Positioned(
            right: wide ? 20 : 0,
            top: 180,
            child: _cloud(132, cloudy ? .68 : .36),
          ),
          if (rain && !night)
            ...List.generate(
              28,
              (i) => Positioned(
                left: (i * 31.0) % (wide ? 800 : 330),
                top: 30 + (i * 47.0) % 230,
                child: Transform.rotate(
                  angle: -.25,
                  child: Container(
                    width: 1.5,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.34),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          if (night)
            ...List.generate(
              18,
              (i) => Positioned(
                left: (i * 73.0) % (wide ? 800 : 330),
                top: (i * 37.0) % 180,
                child: Container(
                  width: 2,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.75),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _place.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _tag('LIVE', Colors.white),
                  PopupMenuButton<String>(
                    tooltip: 'Sky preview',
                    icon: const Icon(Icons.more_horiz, color: Colors.white),
                    onSelected: (v) => setState(() {
                      _manualPreview = v != 'auto';
                      _previewNight = v == 'night';
                    }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'auto',
                        child: Text('Automatic sky'),
                      ),
                      PopupMenuItem(
                        value: 'day',
                        child: Text('Preview daytime'),
                      ),
                      PopupMenuItem(
                        value: 'night',
                        child: Text('Preview nighttime'),
                      ),
                    ],
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
                      Text(
                        _temp(w.temp),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: wide ? 78 : 72,
                          fontWeight: FontWeight.w300,
                          height: 1,
                          letterSpacing: -5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        w.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Feels like ${_temp(w.feels)}  ·  H:${_temp(w.high)}  L:${_temp(w.low)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.85),
                          fontSize: 12,
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sunrise $sunrise    Sunset $sunset',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.82),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (!wide)
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      dt,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      '↑ $sunrise  ·  ↓ $sunset',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _celestial(bool night) => Container(
    width: night ? 104 : 126,
    height: night ? 104 : 126,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: night ? const Color(0xffdce7ed) : const Color(0xffffe39a),
      boxShadow: [
        BoxShadow(
          color: (night ? const Color(0xffe8efff) : const Color(0xffffe9a5))
              .withOpacity(.5),
          blurRadius: 58,
          spreadRadius: 22,
        ),
      ],
    ),
    child: night
        ? const Icon(Icons.nightlight_round, color: Color(0xff8292a2), size: 59)
        : null,
  );
  Widget _cloud(double size, double opacity) => Icon(
    Icons.cloud_rounded,
    size: size,
    color: Colors.white.withOpacity(opacity),
  );
  Widget _tag(String s, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      s,
      style: TextStyle(
        color: c,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ink,
                letterSpacing: -.5,
              ),
            ),
            Text(sub, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      ),
      if (onTap != null)
        TextButton(onPressed: onTap, child: const Text('View all')),
    ],
  );
  Widget _hourStrip(WeatherData w) => Container(
    height: 142,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: _cardDecoration(),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 24,
      separatorBuilder: (_, __) =>
          const VerticalDivider(width: 1, color: Color(0xffedf0f1)),
      itemBuilder: (c, i) {
        final h = w.hourly;
        final temps = (h['temperature_2m'] as List? ?? []);
        final codes = (h['weather_code'] as List? ?? []);
        final times = (h['time'] as List? ?? []);
        final probs = (h['precipitation_probability'] as List? ?? []);
        final winds = (h['wind_speed_10m'] as List? ?? []);
        final start = (times.indexWhere(
          (x) =>
              DateTime.tryParse('$x')
                  ?.isAfter(w.localTime.subtract(const Duration(hours: 1))) ??
              false,
        )).clamp(0, math.max(temps.length - 1, 0)).toInt();
        final n = start + i;
        if (n >= temps.length) return const SizedBox.shrink();
        final time = DateTime.tryParse('${times[n]}') ?? w.localTime;
        return SizedBox(
          width: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                i == 0 ? 'Now' : DateFormat('ha').format(time),
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              Icon(
                weatherIcon(n < codes.length ? (codes[n] as num).toInt() : 0),
                size: 20,
                color: sea,
              ),
              Text(
                _temp(temps[n] as num),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              Text(
                '${n < probs.length ? probs[n] : 0}% · ${(n < winds.length ? (winds[n] as num).round() : 0)} km/h',
                style: const TextStyle(fontSize: 8, color: muted),
              ),
            ],
          ),
        );
      },
    ),
  );
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xffedf0f1)),
  );
  Widget _metric(String label, String value, IconData icon, String foot) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: sea),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: muted,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ink,
                letterSpacing: -1,
              ),
            ),
            Text(
              foot,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ],
        ),
      );
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
  Widget _weekPreview(WeatherData w) =>
      Column(children: List.generate(7, (i) => _dayRow(w, i, compact: true)));
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 10 : 14,
      ),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              i == 0 ? 'Today' : DateFormat('EEE').format(date),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: ink,
              ),
            ),
          ),
          Icon(weatherIcon((codes[i] as num).toInt()), color: sea, size: 20),
          const SizedBox(width: 10),
          if (!compact)
            Expanded(
              child: Text(
                weatherText((codes[i] as num).toInt()),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          if (compact) const Spacer(),
          Text(
            '${rains.isNotEmpty ? rains[i] : 0}%',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(width: 20),
          Text(
            '${(mins[i] as num).round()}°',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text(
              '${(maxs[i] as num).round()}°',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: ink,
                fontSize: 13,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 18),
            Text(
              '${(winds[i] as num).round()} km/h',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(width: 18),
            Text(
              'UV ${(uvs[i] as num).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 11, color: muted),
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
              DateTime.tryParse('$x')
                  ?.isAfter(w.localTime.subtract(const Duration(hours: 1))) ??
              false,
        )
        .clamp(0, math.max(times.length - 1, 0))
        .toInt();
    final pts = <FlSpot>[];
    for (var i = 0; i < 24 && start + i < temps.length; i++)
      pts.add(FlSpot(i.toDouble(), (temps[start + i] as num).toDouble()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Hourly forecast', 'The next 24 hours in ${_place.name}'),
        const SizedBox(height: 18),
        _chart(pts, 'TEMPERATURE', height: 220),
        const SizedBox(height: 20),
        _hourStrip(w),
        const SizedBox(height: 20),
        ...List.generate(24, (i) => _hourRow(w, start + i, i)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              i == 0 ? 'Now' : DateFormat('ha').format(t),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          Icon(weatherIcon((codes[n] as num).toInt()), color: sea, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              weatherText((codes[n] as num).toInt()),
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Text(
            '${probs[n]}%',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(width: 14),
          Text(
            '${(rains[n] as num).toStringAsFixed(1)} mm',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(width: 14),
          Text(
            '${(winds[n] as num).round()} km/h',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(width: 14),
          Text(
            _temp(temps[n] as num),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ink,
              fontSize: 14,
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
        _sectionTitle('7-day forecast', 'A week of weather, at a glance'),
        const SizedBox(height: 18),
        _chart(pts, 'DAILY HIGH', height: 210),
        const SizedBox(height: 18),
        ...List.generate(7, (i) => _dayRow(w, i)),
      ],
    );
  }

  Widget _chart(List<FlSpot> points, String label, {double height = 200}) =>
      Container(
        height: height + 28,
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 6),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 1.2,
                color: muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: math.max(points.length - 1, 1).toDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: const Color(0xffedf0f1), strokeWidth: 1),
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
                        reservedSize: 20,
                        interval: math.max(
                          (points.length / 6).floorToDouble(),
                          1,
                        ),
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            '${value.toInt()}',
                            style: const TextStyle(color: muted, fontSize: 9),
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
                      color: sea,
                      barWidth: 2.5,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: sea.withValues(alpha: .10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        _sectionTitle('Wind intelligence', 'Wind conditions in ${_place.name}'),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Transform.rotate(
                angle: w.bearing * math.pi / 180,
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 84,
                  color: sea,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${w.wind.round()} km/h',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              Text(
                '${_compass(w.bearing)} · ${w.bearing}° bearing',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
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
        const SizedBox(height: 18),
        _chart(pts, 'HOURLY WIND SPEED · KM/H', height: 210),
        const SizedBox(height: 16),
        _sectionTitle('Hourly wind', 'Forecast wind speed'),
        const SizedBox(height: 12),
        _hourStrip(w),
      ],
    );
  }

  Widget _smallStat(String label, String val) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(color: muted, fontSize: 9, letterSpacing: 1),
      ),
      const SizedBox(height: 6),
      Text(
        val,
        style: const TextStyle(
          color: ink,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
  Widget _airSummary() {
    if (_airLoading)
      return Container(
        height: 90,
        decoration: _cardDecoration(),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    if (_air == null)
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: const Text(
          'Air quality readings are currently unavailable for this location.',
          style: TextStyle(color: muted),
        ),
      );
    final a = _air!;
    final aqi = (a['european_aqi'] as num?)?.round();
    final color = aqi == null
        ? muted
        : aqi < 21
        ? const Color(0xff3e9b75)
        : aqi < 41
        ? const Color(0xff98a847)
        : aqi < 61
        ? const Color(0xffdc9e3d)
        : const Color(0xffcc675a);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${aqi ?? '—'}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aqi == null ? 'AQI unavailable' : _aqiLabel(aqi),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Text(
                  'European AQI · Open-Meteo Air Quality',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            'PM₂.₅  ${((a['pm2_5'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: ink,
              fontSize: 12,
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
        ),
        const SizedBox(height: 18),
        _airSummary(),
        if (a != null) ...[
          const SizedBox(height: 18),
          Text(
            'POLLUTANTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          ...[
            _pollutant('PM2.5', 'pm2_5', 'μg/m³'),
            _pollutant('PM10', 'pm10', 'μg/m³'),
            _pollutant('Carbon monoxide', 'carbon_monoxide', 'μg/m³'),
            _pollutant('Nitrogen dioxide', 'nitrogen_dioxide', 'μg/m³'),
            _pollutant('Ozone', 'ozone', 'μg/m³'),
            _pollutant('Sulphur dioxide', 'sulphur_dioxide', 'μg/m³'),
          ],
          const SizedBox(height: 12),
          Text(
            'Readings are supplied by Open-Meteo. AQI uses the European scale (0–100+). Forecast model estimates may not reflect local roadside conditions.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _pollutant(String name, String key, String unit) {
    final n = (_air?[key] as num?)?.toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
            ),
          ),
          Text(
            n == null ? 'Unavailable' : '${n.toStringAsFixed(1)} $unit',
            style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _mapPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Weather map', 'Explore ${_place.name} and the world'),
      const SizedBox(height: 14),
      Container(
        height: MediaQuery.sizeOf(context).height * .62,
        clipBehavior: Clip.antiAlias,
        decoration: _cardDecoration(),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(_place.lat, _place.lon),
            initialZoom: 7,
            onTap: (tap, point) => _inspect(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.aether.weather',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_place.lat, _place.lon),
                  width: 46,
                  height: 46,
                  child: const Icon(Icons.location_on, color: sea, size: 42),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  '© OpenStreetMap contributors',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Map data © OpenStreetMap contributors'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: sea),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Map tiles show geographic data only. Live weather overlays require a licensed tile source and are not available in this build.',
                style: TextStyle(color: muted, fontSize: 12),
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
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${point.latitude.toStringAsFixed(2)}, ${point.longitude.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(cur['temperature_2m'] as num).round()}° · ${weatherText(cur['weather_code'])}',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 12),
              FilledButton(
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
                child: const Text('Use this location'),
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
      ),
      const SizedBox(height: 14),
      _searchBox(),
      const SizedBox(height: 20),
      _sectionTitle('Recent searches', 'Your recently viewed locations'),
      const SizedBox(height: 10),
      if (_recent.isEmpty)
        const Text(
          'Locations you view will appear here.',
          style: TextStyle(color: muted),
        ),
      ..._recent.map((p) => _placeRow(p)),
      const SizedBox(height: 18),
      _sectionTitle('Favorites', 'Saved for quick access'),
      const SizedBox(height: 10),
      if (_favorites.isEmpty)
        const Text(
          'Tap the star next to a city to save it.',
          style: TextStyle(color: muted),
        ),
      ..._favorites.map((p) => _placeRow(p, favorite: true)),
    ],
  );
  Widget _placeRow(Place p, {bool favorite = false}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: _cardDecoration(),
    child: ListTile(
      leading: const Icon(Icons.location_on_outlined, color: sea),
      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(p.country),
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
        ),
        const SizedBox(height: 15),
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
              if (!s.hasData)
                return Container(
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: _cardDecoration(),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              final x = s.data!.data['current'];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(weatherIcon(x['weather_code']), color: sea),
                    const SizedBox(width: 10),
                    Text(
                      '${(x['temperature_2m'] as num).round()}°',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      '${(x['wind_speed_10m'] as num).round()} km/h',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add a favorite from Global locations to include another city.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _aboutPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Weather, with a little more atmosphere', 'AETHER WEATHER'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: _cardDecoration(),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A calmer way to read the sky.',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Aether brings current conditions, forecasts and atmospheric context together in one considered view. The sky preview follows the selected location’s local sunrise and sunset; manual previews change the artwork only.',
              style: TextStyle(color: muted, height: 1.7),
            ),
            SizedBox(height: 18),
            Text(
              'DATA SOURCES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: sea,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Weather forecast · Open-Meteo\nAir quality · Open-Meteo\nMap tiles · © OpenStreetMap contributors',
              style: TextStyle(color: ink, height: 1.8),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _settingsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Settings', 'Make Aether feel like yours'),
      const SizedBox(height: 16),
      Container(
        decoration: _cardDecoration(),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Temperature in Fahrenheit'),
              subtitle: const Text('Turn off for Celsius'),
              value: _fahrenheit,
              onChanged: (v) async {
                setState(() => _fahrenheit = v);
                await _persist();
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Preview night sky'),
              subtitle: const Text(
                'Visual preview only · weather data stays unchanged',
              ),
              value: _manualPreview && _previewNight,
              onChanged: (v) => setState(() {
                _manualPreview = true;
                _previewNight = v;
              }),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Automatic sky mode'),
              subtitle: const Text(
                'Use this location’s local sunrise and sunset',
              ),
              trailing: TextButton(
                onPressed: () => setState(() => _manualPreview = false),
                child: const Text('Reset'),
              ),
              onTap: () => setState(() => _manualPreview = false),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Wind speed'),
              subtitle: const Text('Kilometres per hour'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _sectionTitle(
        'Current location',
        '${_place.lat.toStringAsFixed(3)}, ${_place.lon.toStringAsFixed(3)} · ${_weather?.timezone ?? '—'}',
      ),
      const SizedBox(height: 10),
      Container(
        decoration: _cardDecoration(),
        child: ListTile(
          leading: const Icon(Icons.location_on, color: sea),
          title: Text(_place.label),
          subtitle: Text(
            'Weather updated ${_weather == null ? '—' : DateFormat('HH:mm').format(_weather!.localTime)} local time',
          ),
          trailing: IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ),
      ),
    ],
  );
  Widget _sideHeading(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: 1.4,
        color: muted,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
  Widget _errorBanner() => Container(
    color: const Color(0xfffff1ea),
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        const Icon(Icons.wifi_off, color: Color(0xffbd6b45)),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12))),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );
}
