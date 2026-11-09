import 'package:flutter/material.dart';

/// Reusable rounded surface for dashboard and detail content.
class AtmosCard extends StatelessWidget {
  const AtmosCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffe5ebea)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0a101922),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}
