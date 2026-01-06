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
          _contests = contests.take(3).toList();
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD700),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'CONTESTS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadContests,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.refresh,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
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
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF58A6FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
          else if (_contests.isEmpty)
            Center(
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
            )
          else
            ..._contests.map((contest) => _buildContestItem(contest)),
        ],
      ),
    );
  }

  Widget _buildContestItem(Contest contest) {
    final isEnded = contest.isEnded;
    final hasStarted = contest.hasStarted;

    final sortedParticipants = List<ContestParticipant>.from(contest.participants)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final topTwo = sortedParticipants.take(2).toList();
    final maxScore = topTwo.isNotEmpty ? topTwo.first.totalScore : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              _buildStatusBadge(isEnded, hasStarted),
            ],
          ),
          const SizedBox(height: 12),
          if (topTwo.isEmpty)
            Text(
              'No participants yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            )
          else
            ...topTwo.asMap().entries.map((entry) => 
              _buildParticipantProgressBar(
                entry.value, 
                entry.key, 
                maxScore > 0 ? maxScore : 1,
                isEnded,
              ),
            ),
        ],
      ),
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
                  if (rank == 0)
                    Icon(
                      isEnded ? Icons.emoji_events : Icons.arrow_upward,
                      size: 12,
                      color: color,
                    ),
                  if (rank == 0) const SizedBox(width: 4),
                  Text(
                    participant.userName,
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
