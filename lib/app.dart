import 'package:flutter/material.dart';

import 'core/theme/atmos_theme.dart';

/// Application composition root. Feature screens are supplied by the entrypoint.
class AtmosApp extends StatelessWidget {
  const AtmosApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ATMOS – Ultimate Smart Weather',
    debugShowCheckedModeBanner: false,
    theme: AtmosTheme.light,
    home: home,
  );
}
