import 'package:flutter/material.dart';

import '../main.dart' show DailyTrackerHome;

class IOSDashboardScreen extends StatelessWidget {
  const IOSDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DailyTrackerHome(showSidebar: false);
  }
}
