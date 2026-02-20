import 'package:flutter/material.dart';
import '../theme/glassmorphism_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Apple glassmorphism active contests card
/// Shows active and ended contests
class GlassContestsCard extends StatefulWidget {
  const GlassContestsCard({super.key});

  @override
  State<GlassContestsCard> createState() => _GlassContestsCardState();
}

class _GlassContestsCardState extends State<GlassContestsCard> {
  List<dynamic> _activeContests = [];
  List<dynamic> _endedContests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContests();
  }

  Future<void> _loadContests() async {
    try {
      final userId = AuthService.currentUser?.id ?? '';
      final contests = await ApiService.getUserContests(userId);
      
      if (mounted) {
        setState(() {
          _activeContests = contests.where((c) => c['status'] == 'active').toList();
          _endedContests = contests.where((c) => c['status'] == 'ended').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading contests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_activeContests.isEmpty) ...[
            // Empty state
            Center(
              child: Column(
                children: [
                  Text(
                    '🏆',
                    style: TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No active contests',
                    style: TextStyle(
                      fontSize: 14,
                      color: GlassTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      // Navigate to create contest
                    },
                    child: Text(
                      'Create one →',
                      style: TextStyle(
                        fontSize: 14,
                        color: GlassTheme.accentCyan,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Active contests
            ...(_activeContests.map((contest) => _buildContestItem(
              contest,
              isActive: true,
            ))),
          ],
          
          // Ended section
          if (_endedContests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Ended',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GlassTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...(_endedContests.take(2).map((contest) => _buildContestItem(
              contest,
              isActive: false,
            ))),
          ],
        ],
      ),
    );
  }

  Widget _buildContestItem(dynamic contest, {required bool isActive}) {
    final name = contest['name'] ?? 'Contest';
    final points = contest['userPoints'] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: GlassTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Contest info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🏆 ', style: TextStyle(fontSize: 12)),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '🏆 Dev · $points pts',
                  style: TextStyle(
                    fontSize: 12,
                    color: GlassTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          
          // Check mark for ended
          if (!isActive)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: GlassTheme.accentMint.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check,
                size: 14,
                color: GlassTheme.accentMint,
              ),
            ),
        ],
      ),
    );
  }
}
