import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../screens/contest_screen.dart';

class ContestRefreshNotifier extends ChangeNotifier {
  static final ContestRefreshNotifier _instance = ContestRefreshNotifier._internal();
  factory ContestRefreshNotifier() => _instance;
  ContestRefreshNotifier._internal();

  void refresh() {
    notifyListeners();
  }
}

final contestRefreshNotifier = ContestRefreshNotifier();

class ContestsDashboardWidget extends StatefulWidget {
  const ContestsDashboardWidget({super.key});

  @override
  State<ContestsDashboardWidget> createState() => _ContestsDashboardWidgetState();
}

class _ContestsDashboardWidgetState extends State<ContestsDashboardWidget> with WidgetsBindingObserver {
  List<Contest> _contests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    contestRefreshNotifier.addListener(_loadContests);
    _loadContests();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    contestRefreshNotifier.removeListener(_loadContests);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadContests();
    }
  }

  Future<void> _loadContests() async {
    try {
      final contests = await ApiService.getContests();
      if (mounted) {
        setState(() {
          _contests = contests; // Keep all contests to filter active vs ended
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate active and ended contests
    final activeContests = _contests.where((c) => c.hasStarted && !c.isEnded).toList();
    final endedContests = _contests.where((c) => c.isEnded).toList()
      ..sort((a, b) => DateTime.parse(b.endDate).compareTo(DateTime.parse(a.endDate)));
    final lastEndedContest = endedContests.isNotEmpty ? endedContests.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Contest Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE CONTESTS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 0.5,
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContestScreen()),
                );
                _loadContests();
              },
              child: Text(
                'View all',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (activeContests.isEmpty)
          _buildEmptyActiveState()
        else
          ...activeContests.map((contest) => _buildActiveContestCard(
            contest,
            List<ContestParticipant>.from(contest.participants)
              ..sort((a, b) => b.totalScore.compareTo(a.totalScore)),
          )),
        
        const SizedBox(height: 24),
        
        // Ended Section
        const Text(
          'Ended',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (lastEndedContest != null)
          _buildEndedContestItem(lastEndedContest)
        else
          Text(
            'No ended contests yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyActiveState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'No active contests',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContestScreen()),
                );
              },
              child: const Text(
                'Create one →',
                style: TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndedContestItem(Contest contest) {
    final sortedParticipants = List<ContestParticipant>.from(contest.participants)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final topThree = sortedParticipants.take(3).toList();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Stacked avatars (small)
          SizedBox(
            width: 52,
            height: 28,
            child: Stack(
              children: topThree.asMap().entries.map((entry) {
                final index = entry.key;
                final participant = entry.value;
                return Positioned(
                  left: index * 12.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1A1D24),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: participant.userPhoto != null && participant.userPhoto!.isNotEmpty
                          ? Image.network(participant.userPhoto!, fit: BoxFit.cover)
                          : Container(
                              color: Colors.white.withValues(alpha: 0.1),
                              child: Center(
                                child: Text(
                                  _getFirstName(participant.userName).isNotEmpty
                                      ? _getFirstName(participant.userName)[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              }).toList(),
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
                    const Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        contest.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  topThree.isNotEmpty 
                      ? '🏆 ${_getFirstName(topThree.first.userName)} • ${topThree.first.totalScore} pts'
                      : 'No participants',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Ended badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Ended',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFirstName(String fullName) {
    return fullName.split(' ').first;
  }

  Widget _buildContestItem(Contest contest) {
    final isEnded = contest.isEnded;
    final hasStarted = contest.hasStarted;

    final sortedParticipants = List<ContestParticipant>.from(contest.participants)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    if (isEnded) {
      return _buildEndedContestCard(contest, sortedParticipants);
    } else if (hasStarted) {
      return _buildActiveContestCard(contest, sortedParticipants);
    } else {
      return _buildUpcomingContestCard(contest, sortedParticipants);
    }
  }

  Widget _buildActiveContestCard(Contest contest, List<ContestParticipant> sortedParticipants) {
    final isEnded = contest.isEnded;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contest name + status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: Color(0xFFFFD700),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    contest.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(isEnded, contest.hasStarted),
            ],
          ),
          const SizedBox(height: 12),
          // Participant rows
          ...sortedParticipants.asMap().entries.map((entry) {
            final index = entry.key;
            final participant = entry.value;
            
            // Check for ties - find actual rank considering ties
            int actualRank = 0;
            bool isTied = false;
            for (int i = 0; i < sortedParticipants.length; i++) {
              if (i < index && sortedParticipants[i].totalScore == participant.totalScore) {
                isTied = true;
              }
              if (i > 0 && sortedParticipants[i].totalScore < sortedParticipants[i - 1].totalScore) {
                actualRank = i;
              }
              if (i == index) {
                if (i > 0 && sortedParticipants[i].totalScore == sortedParticipants[i - 1].totalScore) {
                  isTied = true;
                }
                break;
              }
            }
            // Check if next person also has same score
            if (index < sortedParticipants.length - 1 && 
                sortedParticipants[index + 1].totalScore == participant.totalScore) {
              isTied = true;
            }
            
            // Calculate actual rank (same score = same rank)
            actualRank = 0;
            for (int i = 0; i < index; i++) {
              if (sortedParticipants[i].totalScore > participant.totalScore) {
                actualRank++;
              }
            }
            
            return _buildParticipantRow(participant, actualRank, isEnded, isTied);
          }),
        ],
      ),
    );
  }

  Widget _buildParticipantRow(ContestParticipant participant, int rank, bool isEnded, bool isTied) {
    final isLeader = rank == 0;
    final firstName = _getFirstName(participant.userName);
    
    // Medal icons
    const medals = ['🥇', '🥈', '🥉'];
    final medalIcon = rank < 3 ? medals[rank] : '';
    
    // Colors
    final bgColor = isLeader 
        ? const Color(0xFF4A4A2E) // Olive/gold tint for leader
        : const Color(0xFF2A2D35); // Dark grey for others
    final borderColor = isLeader 
        ? const Color(0xFF7A7A3E) // Gold border for leader
        : Colors.transparent;
    final pointsColor = isLeader 
        ? const Color(0xFFB8D86B) // Bright green/gold for leader
        : Colors.white.withValues(alpha: 0.7);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isLeader ? 1.5 : 0),
      ),
      child: Row(
        children: [
          // Medal
          SizedBox(
            width: 28,
            child: Text(
              medalIcon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: participant.userPhoto != null && participant.userPhoto!.isNotEmpty
                  ? Image.network(
                      participant.userPhoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildInitialAvatar(firstName),
                    )
                  : _buildInitialAvatar(firstName),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              firstName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Draw badge if tied
          if (isTied) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getDrawBadgeColor(rank).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Draw',
                style: TextStyle(
                  color: _getDrawBadgeColor(rank),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Points
          Text(
            '${participant.totalScore} pts',
            style: TextStyle(
              color: pointsColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(String name) {
    return Container(
      color: const Color(0xFF3D4252),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getDrawBadgeColor(int rank) {
    switch (rank) {
      case 0:
        return const Color(0xFFFFD700); // Gold
      case 1:
        return const Color(0xFFC0C0C0); // Silver
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF888888); // Grey for 4th+
    }
  }

  Widget _buildAvatarsRow(List<ContestParticipant> participants) {
    final displayParticipants = participants.take(4).toList();
    if (displayParticipants.isEmpty) return const SizedBox.shrink();

    final leader = displayParticipants.first;
    final others = displayParticipants.skip(1).toList();

    const double leaderSize = 100;
    const double otherSize = 70;
    const double overlap = 25;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Others (overlapping, on left)
        if (others.isNotEmpty)
          SizedBox(
            width: otherSize + (others.length - 1) * (otherSize - overlap),
            height: otherSize,
            child: Stack(
              children: others.asMap().entries.map((entry) {
                final index = entry.key;
                final participant = entry.value;
                
                // Pastel colors
                final colors = [
                  const Color(0xFFFFD6E8), // Pink
                  const Color(0xFFD6FFE8), // Mint
                  const Color(0xFFE8D6FF), // Lavender
                ];
                final bgColor = colors[index % colors.length];

                return Positioned(
                  left: index * (otherSize - overlap),
                  child: Container(
                    width: otherSize,
                    height: otherSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bgColor,
                      border: Border.all(
                        color: const Color(0xFF262A35),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: participant.userPhoto != null && participant.userPhoto!.isNotEmpty
                          ? Image.network(
                              participant.userPhoto!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: bgColor,
                                child: Center(
                                  child: Text(
                                    _getFirstName(participant.userName).isNotEmpty
                                        ? _getFirstName(participant.userName)[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: bgColor,
                              child: Center(
                                child: Text(
                                  _getFirstName(participant.userName).isNotEmpty
                                      ? _getFirstName(participant.userName)[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        
        SizedBox(width: others.isNotEmpty ? 16 : 0),
        
        // Leader (on right, with crown)
        Column(
          children: [
            // Crown
            const Text(
              '👑',
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 4),
            // Leader avatar with gold ring and glow
            Container(
              width: leaderSize,
              height: leaderSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4A853),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4A853).withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: leader.userPhoto != null && leader.userPhoto!.isNotEmpty
                    ? Image.network(
                        leader.userPhoto!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFFFE4E8),
                          child: Center(
                            child: Text(
                              _getFirstName(leader.userName).isNotEmpty
                                  ? _getFirstName(leader.userName)[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFFD4A853),
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFFFE4E8),
                        child: Center(
                          child: Text(
                            _getFirstName(leader.userName).isNotEmpty
                                ? _getFirstName(leader.userName)[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFFD4A853),
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBarWithInitials(List<ContestParticipant> participants) {
    final displayParticipants = participants.take(4).toList();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        
        return SizedBox(
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Bar background
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF5B7FD1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Position dots with initials
              ...displayParticipants.asMap().entries.map((entry) {
                final index = entry.key;
                final participant = entry.value;
                final total = displayParticipants.length;
                
                // Leader (index 0) on the right, others spread left
                double position;
                if (total == 1) {
                  position = 0.85;
                } else {
                  position = 0.85 - (index / (total - 1)) * 0.7;
                }
                
                final isLeader = index == 0;
                final leftPos = position * barWidth - 18;
                final firstName = _getFirstName(participant.userName);
                final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
                
                return Positioned(
                  left: leftPos.clamp(0, barWidth - 36),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLeader ? const Color(0xFFD4A853) : const Color(0xFF5B7FD1),
                      border: Border.all(
                        color: isLeader ? const Color(0xFFD4A853) : const Color(0xFF3A4D7A),
                        width: 3,
                      ),
                      boxShadow: isLeader
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD4A853).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: isLeader ? const Color(0xFF262A35) : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4757).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4757),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Live',
            style: TextStyle(
              color: Color(0xFFFF4757),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlappingAvatars(List<ContestParticipant> participants) {
    final displayParticipants = participants.take(4).toList();
    const double leaderSize = 80;
    const double regularSize = 60;
    const double overlap = 20;
    
    if (displayParticipants.isEmpty) return const SizedBox.shrink();
    
    // Calculate total width: leader + others with overlap
    final othersCount = displayParticipants.length - 1;
    final totalWidth = leaderSize + (othersCount * (regularSize - overlap));

    return SizedBox(
      height: leaderSize + 24, // Extra space for crown
      width: totalWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Leader (first/leftmost) with crown
          if (displayParticipants.isNotEmpty)
            Positioned(
              left: 0,
              top: 0,
              child: Column(
                children: [
                  // Crown above leader
                  const Text(
                    '👑',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  // Leader avatar with gold ring
                  Container(
                    width: leaderSize,
                    height: leaderSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4A853),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4A853).withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: displayParticipants.first.userPhoto != null && 
                             displayParticipants.first.userPhoto!.isNotEmpty
                          ? Image.network(
                              displayParticipants.first.userPhoto!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(
                                displayParticipants.first, 
                                const Color(0xFFD4A853),
                              ),
                            )
                          : _buildAvatarPlaceholder(
                              displayParticipants.first, 
                              const Color(0xFFD4A853),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          // Other participants (overlapping to the right)
          ...displayParticipants.skip(1).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final participant = entry.value;
            
            // Pastel colors for other participants
            final colors = [
              const Color(0xFFF5F5DC), // Beige/cream
              const Color(0xFFE8D5E8), // Light purple/pink
              const Color(0xFFD5E8E8), // Light blue/gray
            ];
            final bgColor = colors[index % colors.length];

            return Positioned(
              left: leaderSize + (index * (regularSize - overlap)) - overlap,
              top: 28, // Align with leader avatar (below crown)
              child: Container(
                width: regularSize,
                height: regularSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: Border.all(
                    color: const Color(0xFF1A1D2E),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: participant.userPhoto != null && participant.userPhoto!.isNotEmpty
                      ? Image.network(
                          participant.userPhoto!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: bgColor,
                            child: Center(
                              child: Text(
                                _getFirstName(participant.userName).isNotEmpty
                                    ? _getFirstName(participant.userName)[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: bgColor,
                          child: Center(
                            child: Text(
                              _getFirstName(participant.userName).isNotEmpty
                                  ? _getFirstName(participant.userName)[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(ContestParticipant participant, Color color) {
    return Container(
      color: color.withValues(alpha: 0.3),
      child: Center(
        child: Text(
          _getFirstName(participant.userName).isNotEmpty
              ? _getFirstName(participant.userName)[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientProgressBar(List<ContestParticipant> participants) {
    if (participants.isEmpty) return const SizedBox.shrink();

    final maxScore = participants.first.totalScore;
    final minScore = participants.last.totalScore;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        
        return SizedBox(
          height: 12,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient bar background
              Container(
                height: 8,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF58A6FF), // Blue
                      Color(0xFFBB86FC), // Purple
                      Color(0xFFFF6B9D), // Pink
                      Color(0xFFFFD700), // Gold
                    ],
                  ),
                ),
              ),
              // Position indicators for each participant
              ...participants.take(4).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final participant = entry.value;
                
                // Calculate position based on score
                double position;
                if (maxScore == minScore) {
                  position = 0.5;
                } else {
                  position = (participant.totalScore - minScore) / (maxScore - minScore);
                }
                
                // Clamp position and add padding
                final leftPos = (position * 0.85 + 0.05) * barWidth - 6;
                
                return Positioned(
                  left: leftPos.clamp(0, barWidth - 12),
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: index == 0 ? const Color(0xFFFFD700) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingContestCard(Contest contest, List<ContestParticipant> sortedParticipants) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                size: 14,
                color: Color(0xFFFFD700),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  contest.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(false, false),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${sortedParticipants.length} participants ready',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedContestCard(Contest contest, List<ContestParticipant> sortedParticipants) {
    final topParticipants = sortedParticipants.take(3).toList();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                size: 14,
                color: Color(0xFFFFD700),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  contest.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(true, true),
            ],
          ),
          const SizedBox(height: 12),
          if (topParticipants.isEmpty)
            Text(
              'No participants',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            )
          else
            _buildEndedContestPodium(topParticipants),
        ],
      ),
    );
  }

  Widget _buildEndedContestPodium(List<ContestParticipant> topThree) {
    const rankLabels = ['🥇', '🥈', '🥉'];
    const rankColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    
    return Column(
      children: topThree.asMap().entries.map((entry) {
        final rank = entry.key;
        final participant = entry.value;
        final color = rankColors[rank];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: rank == 0 
                ? color.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: rank == 0 
                ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Text(
                rankLabels[rank],
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 10),
              // User avatar
              if (participant.userPhoto != null && participant.userPhoto!.isNotEmpty)
                CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage(participant.userPhoto!),
                )
              else
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.3),
                  child: Text(
                    _getFirstName(participant.userName).isNotEmpty 
                        ? _getFirstName(participant.userName)[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getFirstName(participant.userName),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: rank == 0 ? FontWeight.w600 : FontWeight.w500,
                    color: rank == 0 ? color : Colors.white,
                  ),
                ),
              ),
              Text(
                '${participant.totalScore} pts',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: rank == 0 ? color : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParticipantProgressBar(
    ContestParticipant participant, 
    int rank, 
    int maxScore,
    bool isEnded,
  ) {
    final progress = maxScore > 0 ? participant.totalScore / maxScore : 0.0;
    final color = rank == 0 
        ? (isEnded ? const Color(0xFFFFD700) : const Color(0xFF30D158))
        : const Color(0xFF58A6FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // User avatar
                  if (participant.userPhoto != null && participant.userPhoto!.isNotEmpty)
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(participant.userPhoto!),
                    )
                  else
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: color.withValues(alpha: 0.3),
                      child: Text(
                        _getFirstName(participant.userName).isNotEmpty 
                            ? _getFirstName(participant.userName)[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (rank == 0)
                    Icon(
                      isEnded ? Icons.emoji_events : Icons.arrow_upward,
                      size: 12,
                      color: color,
                    ),
                  if (rank == 0) const SizedBox(width: 4),
                  Text(
                    _getFirstName(participant.userName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                '${participant.totalScore} pts',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isEnded, bool hasStarted) {
    Color bgColor;
    Color textColor;
    String text;

    if (isEnded) {
      bgColor = const Color(0xFF238636).withValues(alpha: 0.2);
      textColor = const Color(0xFF3FB950);
      text = 'Ended';
    } else if (hasStarted) {
      bgColor = const Color(0xFF58A6FF).withValues(alpha: 0.2);
      textColor = const Color(0xFF58A6FF);
      text = 'Active';
    } else {
      bgColor = const Color(0xFFF0883E).withValues(alpha: 0.2);
      textColor = const Color(0xFFF0883E);
      text = 'Upcoming';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
