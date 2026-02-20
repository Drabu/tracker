import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/contests_dashboard_widget.dart' show contestRefreshNotifier;
import 'contest_screen.dart';

class ContestInvitePage extends StatefulWidget {
  final String contestId;

  const ContestInvitePage({super.key, required this.contestId});

  @override
  State<ContestInvitePage> createState() => _ContestInvitePageState();
}

class _ContestInvitePageState extends State<ContestInvitePage> {
  Contest? _contest;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _error;

  String get _currentUserId => AuthService.currentUser?.id ?? '';

  bool get _alreadyJoined =>
      _contest?.participants.any((p) => p.userId == _currentUserId) ?? false;

  @override
  void initState() {
    super.initState();
    _loadContest();
  }

  Future<void> _loadContest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final contest = await ApiService.getContest(widget.contestId);
      if (mounted) {
        setState(() {
          _contest = contest;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinContest() async {
    setState(() => _isJoining = true);
    try {
      await ApiService.joinContest(widget.contestId, _currentUserId);
      contestRefreshNotifier.refresh();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ContestScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join contest: $e')),
        );
      }
    }
  }

  void _openContest() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ContestScreen()),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _contestStatus(Contest contest) {
    if (contest.isEnded) return 'Ended';
    if (contest.hasStarted) return 'Active';
    return 'Upcoming';
  }

  Color _statusColor(Contest contest) {
    if (contest.isEnded) return Colors.red;
    if (contest.hasStarted) return const Color(0xFF39D353);
    return const Color(0xFF58A6FF);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load contest',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadContest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                ),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final contest = _contest!;
    final participantCount = contest.participants.length;
    final totalPoints =
        contest.participants.fold<int>(0, (sum, p) => sum + p.totalScore);
    final status = _contestStatus(contest);
    final statusClr = _statusColor(contest);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 56),
              const SizedBox(height: 16),
              Text(
                'CONTEST INVITE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                contest.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (contest.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  contest.description,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: statusClr.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusClr.withOpacity(0.4)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      color: statusClr,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              _infoRow(Icons.calendar_today,
                  '${_formatDate(contest.startDate)} - ${_formatDate(contest.endDate)}'),
              const SizedBox(height: 12),
              _infoRow(Icons.people_outline,
                  '$participantCount participant${participantCount == 1 ? '' : 's'}'),
              const SizedBox(height: 12),
              _infoRow(Icons.star_outline, '$totalPoints total points'),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _alreadyJoined
                    ? ElevatedButton(
                        onPressed: _openContest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF238636),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Open Contest',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      )
                    : ElevatedButton(
                        onPressed: _isJoining ? null : _joinContest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF238636),
                          disabledBackgroundColor:
                              const Color(0xFF238636).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isJoining
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Join Contest',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.5), size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
      ],
    );
  }
}
