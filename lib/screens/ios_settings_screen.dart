import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart' show Colors;

class IOSSettingsScreen extends StatelessWidget {
  final VoidCallback onSelectDate;
  final VoidCallback onContests;
  final VoidCallback onTimelineConfig;
  final VoidCallback onPanelConfig;
  final VoidCallback onHabitList;
  final VoidCallback onShowGlassDashboard;
  final VoidCallback onTestSound;
  final VoidCallback onIntegrations;
  final VoidCallback onLogout;

  const IOSSettingsScreen({
    super.key,
    required this.onSelectDate,
    required this.onContests,
    required this.onTimelineConfig,
    required this.onPanelConfig,
    required this.onHabitList,
    required this.onShowGlassDashboard,
    required this.onTestSound,
    required this.onIntegrations,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0D1117),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        middle: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),
            if (kDebugMode) ...[
              _buildSettingsSection(
                'Debug',
                [
                  _SettingsItem(
                    icon: CupertinoIcons.sparkles,
                    iconColor: const Color(0xFF22D3EE),
                    title: 'Glass Dashboard',
                    onTap: onShowGlassDashboard,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            _buildSettingsSection(
              'General',
              [
                _SettingsItem(
                  icon: CupertinoIcons.calendar,
                  iconColor: const Color(0xFF58A6FF),
                  title: 'Select Date',
                  onTap: onSelectDate,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSettingsSection(
              'App',
              [
                _SettingsItem(
                  icon: CupertinoIcons.rosette,
                  iconColor: const Color(0xFFFFD700),
                  title: 'Contests',
                  onTap: onContests,
                ),
                _SettingsItem(
                  icon: CupertinoIcons.clock,
                  iconColor: const Color(0xFF30D158),
                  title: 'Timeline Config',
                  onTap: onTimelineConfig,
                ),
                _SettingsItem(
                  icon: CupertinoIcons.square_grid_2x2,
                  iconColor: const Color(0xFFFF9F0A),
                  title: 'Panel Config',
                  onTap: onPanelConfig,
                ),
                _SettingsItem(
                  icon: CupertinoIcons.list_bullet,
                  iconColor: const Color(0xFF58A6FF),
                  title: 'Habit List',
                  onTap: onHabitList,
                ),
                _SettingsItem(
                  icon: CupertinoIcons.speaker_2,
                  iconColor: const Color(0xFF5856D6),
                  title: 'Test Sound',
                  onTap: onTestSound,
                ),
                _SettingsItem(
                  icon: CupertinoIcons.link,
                  iconColor: const Color(0xFFAF52DE),
                  title: 'Integrations',
                  onTap: onIntegrations,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSettingsSection(
              'Account',
              [
                _SettingsItem(
                  icon: CupertinoIcons.square_arrow_left,
                  iconColor: const Color(0xFFFF453A),
                  title: 'Logout',
                  isDestructive: true,
                  onTap: onLogout,
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<_SettingsItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: item.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: item.iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.icon,
                              size: 18,
                              color: item.iconColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 16,
                                color: item.isDestructive
                                    ? const Color(0xFFFF453A)
                                    : Colors.white,
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      margin: const EdgeInsets.only(left: 62),
                      height: 0.5,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });
}
