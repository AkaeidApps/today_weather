import 'package:flutter/material.dart';

class HourlyAirQuality {
  const HourlyAirQuality({
    required this.time,
    required this.europeanAqi,
    required this.usAqi,
    required this.pm2_5,
    required this.pm10,
  });

  final DateTime time;
  final int? europeanAqi;
  final int? usAqi;
  final double? pm2_5;
  final double? pm10;
}

class AirQualityData {
  const AirQualityData({
    required this.europeanAqi,
    required this.usAqi,
    required this.pm2_5,
    required this.pm10,
    required this.carbonMonoxide,
    required this.nitrogenDioxide,
    required this.ozone,
    required this.sulphurDioxide,
    required this.hourly,
    required this.fetchedAt,
    required this.rawJson,
  });

  final int? europeanAqi;
  final int? usAqi;
  final double? pm2_5;
  final double? pm10;
  final double? carbonMonoxide;
  final double? nitrogenDioxide;
  final double? ozone;
  final double? sulphurDioxide;
  final List<HourlyAirQuality> hourly;
  final DateTime fetchedAt;
  final Map<String, dynamic> rawJson;

  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    final cur = Map<String, dynamic>.from(json['current'] ?? {});
    final euroAqi = (cur['european_aqi'] as num?)?.round();
    final usaAqi = (cur['us_aqi'] as num?)?.round();
    final pm25 = (cur['pm2_5'] as num?)?.toDouble();
    final pm10Val = (cur['pm10'] as num?)?.toDouble();
    final co = (cur['carbon_monoxide'] as num?)?.toDouble();
    final no2 = (cur['nitrogen_dioxide'] as num?)?.toDouble();
    final o3 = (cur['ozone'] as num?)?.toDouble();
    final so2 = (cur['sulphur_dioxide'] as num?)?.toDouble();

    final hourlyMap = Map<String, dynamic>.from(json['hourly'] ?? {});
    final times = hourlyMap['time'] as List? ?? [];
    final euroList = hourlyMap['european_aqi'] as List? ?? [];
    final usList = hourlyMap['us_aqi'] as List? ?? [];
    final pm25List = hourlyMap['pm2_5'] as List? ?? [];
    final pm10List = hourlyMap['pm10'] as List? ?? [];

    final hourly = <HourlyAirQuality>[];
    for (int i = 0; i < times.length; i++) {
      final t = DateTime.tryParse('${times[i]}');
      if (t == null) continue;
      hourly.add(
        HourlyAirQuality(
          time: t,
          europeanAqi: (i < euroList.length ? euroList[i] as num? : null)?.round(),
          usAqi: (i < usList.length ? usList[i] as num? : null)?.round(),
          pm2_5: (i < pm25List.length ? pm25List[i] as num? : null)?.toDouble(),
          pm10: (i < pm10List.length ? pm10List[i] as num? : null)?.toDouble(),
        ),
      );
    }

    return AirQualityData(
      europeanAqi: euroAqi,
      usAqi: usaAqi,
      pm2_5: pm25,
      pm10: pm10Val,
      carbonMonoxide: co,
      nitrogenDioxide: no2,
      ozone: o3,
      sulphurDioxide: so2,
      hourly: hourly,
      fetchedAt: DateTime.now(),
      rawJson: json,
    );
  }

  /// European Air Quality Index status
  ({String label, Color color, String description, String advice}) get europeanStatus {
    final aqi = europeanAqi;
    if (aqi == null) {
      return (
        label: 'Unavailable',
        color: const Color(0xff8a9ba8),
        description: 'Air quality index could not be determined.',
        advice: 'No local reading available.',
      );
    }
    if (aqi <= 20) {
      return (
        label: 'Good',
        color: const Color(0xff3ebb75),
        description: 'Air quality is considered satisfactory, and air pollution poses little or no risk.',
        advice: 'Enjoy your usual outdoor activities.',
      );
    }
    if (aqi <= 40) {
      return (
        label: 'Fair',
        color: const Color(0xff85c242),
        description: 'Air quality is acceptable; however, some pollutants may be a moderate health concern.',
        advice: 'Sensitive individuals should consider reducing intense outdoor exertion.',
      );
    }
    if (aqi <= 60) {
      return (
        label: 'Moderate',
        color: const Color(0xfff3a536),
        description: 'Members of sensitive groups may experience mild health effects.',
        advice: 'Anyone experiencing symptoms like cough or throat irritation should consider reducing outdoor exertion.',
      );
    }
    if (aqi <= 80) {
      return (
        label: 'Poor',
        color: const Color(0xfff06236),
        description: 'Everyone may begin to experience health effects; sensitive groups may experience more serious effects.',
        advice: 'Reduce prolonged or heavy outdoor exertion. Keep windows closed if possible.',
      );
    }
    if (aqi <= 100) {
      return (
        label: 'Very Poor',
        color: const Color(0xffd83c3c),
        description: 'Health warnings of emergency conditions. The entire population is more likely to be affected.',
        advice: 'Avoid strenuous outdoor activities. Wear a mask if stepping outside.',
      );
    }
    return (
      label: 'Extremely Poor',
      color: const Color(0xff8c2ba8),
      description: 'Health alert: serious risk of health effects for all individuals.',
      advice: 'Remain indoors with air filtration. Avoid any outdoor physical activity.',
    );
  }

  /// US EPA Air Quality Index status
  ({String label, Color color}) get usStatus {
    final aqi = usAqi;
    if (aqi == null) return (label: 'Unavailable', color: const Color(0xff8a9ba8));
    if (aqi <= 50) return (label: 'Good', color: const Color(0xff3ebb75));
    if (aqi <= 100) return (label: 'Moderate', color: const Color(0xfff3a536));
    if (aqi <= 150) return (label: 'Unhealthy for Sensitive Groups', color: const Color(0xfff06236));
    if (aqi <= 200) return (label: 'Unhealthy', color: const Color(0xffd83c3c));
    if (aqi <= 300) return (label: 'Very Unhealthy', color: const Color(0xff8c2ba8));
    return (label: 'Hazardous', color: const Color(0xff73173d));
  }
}
