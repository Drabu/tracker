import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'contest_screen.dart';
import 'timeline_screen.dart';
import 'social_settings_screen.dart';
import 'habit_list_screen.dart';
import 'panel_config_screen.dart';
import 'timeline_config_screen.dart';
import 'ios_settings_screen.dart';
import '../services/auth_service.dart';
import 'glass_dashboard_screen.dart';
import 'ios_dashboard_screen.dart';

class IOSHomeScreen extends StatefulWidget {
  const IOSHomeScreen({super.key});

  @override
  State<IOSHomeScreen> createState() => _IOSHomeScreenState();
}

class _IOSHomeScreenState extends State<IOSHomeScreen> {
  int _selectedIndex = 0;

  String get _currentUserId => AuthService.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: const Color(0xFF161B22).withValues(alpha: 0.95),
        activeColor: const Color(0xFF58A6FF),
        inactiveColor: Colors.white.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.speedometer),
            activeIcon: Icon(CupertinoIcons.speedometer),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.rosette),
            activeIcon: Icon(CupertinoIcons.rosette),
            label: 'Contests',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.time),
            activeIcon: Icon(CupertinoIcons.time_solid),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            activeIcon: Icon(CupertinoIcons.settings_solid),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return const IOSDashboardScreen();
              case 1:
                return const ContestScreen();
              case 2:
                return TimelineScreen(userId: _currentUserId);
              case 3:
                return IOSSettingsScreen(
                  onSelectDate: () => _showDatePicker(context),
                  onContests: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const ContestScreen()),
                  ),
                  onTimelineConfig: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const TimelineConfigScreen()),
                  ),
                  onPanelConfig: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const PanelConfigScreen()),
                  ),
                  onHabitList: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const HabitListScreen()),
                  ),
                  onShowGlassDashboard: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const GlassDashboardScreen()),
                  ),
                  onTestSound: () => _playAirplaneCallSound(),
                  onIntegrations: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const SocialSettingsScreen()),
                  ),
                  onLogout: () => _handleLogout(context),
                );
              default:
                return const IOSDashboardScreen();
            }
          },
        );
      },
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF58A6FF),
              surface: Color(0xFF161B22),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected: ${picked.day}/${picked.month}/${picked.year}'),
        ),
      );
    }
  }

  void _playAirplaneCallSound() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test sound triggered (iOS tab settings)')),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AuthService.signOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

/// Helper to check if running on iOS
