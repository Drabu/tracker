import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ContestScreen extends StatefulWidget {
  const ContestScreen({super.key});

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> {
  List<Contest> _contests = [];
  bool _isLoading = true;

  String get _currentUserId => AuthService.currentUser?.id ?? '';

  /// Only show contests where the current user is a participant.
  List<Contest> get _myContests =>
      _contests.where((c) => c.participants.any((p) => p.userId == _currentUserId)).toList();

  List<Contest> get _activeContests => _myContests.where((c) => !c.isEnded).toList();
  List<Contest> get _pastContests => _myContests.where((c) => c.isEnded).toList();

  @override
  void initState() {
    super.initState();
    _loadContests();
  }

  Future<void> _loadContests() async {
    setState(() => _isLoading = true);
    try {
      final contests = await ApiService.getContests();
      setState(() {
        _contests = contests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load contests: $e')),
        );
      }
    }
  }

  void _showCreateContestDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateContestDialog(
        onCreated: () => _loadContests(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Contests'),
        backgroundColor: const Color(0xFF161B22),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContests,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateContestDialog,
        backgroundColor: const Color(0xFF238636),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No contests yet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create one to compete with others!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadContests,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Active/Upcoming Contests
                      if (_activeContests.isNotEmpty) ...[
                        _buildSectionHeader('Active & Upcoming', Icons.play_circle_outline, const Color(0xFF58A6FF)),
                        const SizedBox(height: 12),
                        ..._activeContests.map((contest) => ContestCard(
                          contest: contest,
                          onRefresh: _loadContests,
                        )),
                        const SizedBox(height: 24),
                      ],
                      
                      // Past Contests with Winners
                      if (_pastContests.isNotEmpty) ...[
                        _buildSectionHeader('Past Contests', Icons.emoji_events, const Color(0xFFFFD700)),
                        const SizedBox(height: 12),
                        _buildWinnersShowcase(),
                        const SizedBox(height: 16),
                        ..._pastContests.map((contest) => ContestCard(
                          contest: contest,
                          onRefresh: _loadContests,
                        )),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWinnersShowcase() {
    // Get winners from all past contests
    final winners = <Map<String, dynamic>>[];
    for (final contest in _pastContests) {
      if (contest.participants.isNotEmpty) {
        final sorted = List<ContestParticipant>.from(contest.participants)
          ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
        final topScore = sorted.first.totalScore;
        final tiedCount = sorted.where((p) => p.totalScore == topScore).length;
        if (tiedCount == 1) {
          winners.add({
            'contest': contest,
            'winner': sorted.first,
          });
        }
      }
    }

    if (winners.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD700).withOpacity(0.15),
            const Color(0xFF161B22),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech, color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 8),
              Text(
                'Hall of Champions',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: winners.map((data) {
                final contest = data['contest'] as Contest;
                final winner = data['winner'] as ContestParticipant;
                return _buildWinnerCard(contest, winner);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerCard(Contest contest, ContestParticipant winner) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Winner photo with crown
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD700),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: winner.userPhoto != null && winner.userPhoto!.isNotEmpty
                    ? CircleAvatar(
                        radius: 32,
                        backgroundImage: NetworkImage(winner.userPhoto!),
                      )
                    : CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFFFFD700).withOpacity(0.2),
                        child: Text(
                          winner.displayName.isNotEmpty
                              ? winner.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Text('👑', style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Winner name
          Text(
            winner.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Contest name
          Text(
            contest.name,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${winner.totalScore} pts',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class ContestCard extends StatefulWidget {
  final Contest contest;
  final VoidCallback onRefresh;

  const ContestCard({
    super.key,
    required this.contest,
    required this.onRefresh,
  });

  @override
  State<ContestCard> createState() => _ContestCardState();
}

class _ContestCardState extends State<ContestCard> {
  bool _isLoading = false;

  Contest get contest => widget.contest;
  String get _currentUserId => AuthService.currentUser?.id ?? '';
  bool get _isCreator => contest.creatorId == _currentUserId;

  Future<void> _showRenameDialog() async {
    final nameController = TextEditingController(text: contest.name);
    final descController = TextEditingController(text: contest.description);
    DateTime startDate = DateTime.parse(contest.startDate);
    DateTime endDate = DateTime.parse(contest.endDate);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDate(bool isStart) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: isStart ? startDate : endDate,
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
            if (picked != null) {
              setDialogState(() {
                if (isStart) {
                  startDate = picked;
                  if (endDate.isBefore(startDate)) {
                    endDate = startDate.add(const Duration(days: 1));
                  }
                } else {
                  endDate = picked;
                }
              });
            }
          }

          Widget buildDateSelector(String label, DateTime date, VoidCallback onTap) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 8),
                        Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Contest', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: buildDateSelector('Start', startDate, () => pickDate(true))),
                      const SizedBox(width: 16),
                      Expanded(child: buildDateSelector('End', endDate, () => pickDate(false))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Save', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ApiService.updateContest(
          contest.id,
          name: nameController.text.trim(),
          description: descController.text.trim(),
          startDate: startDate.toIso8601String().split('T')[0],
          endDate: DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toIso8601String(),
        );
        widget.onRefresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
    nameController.dispose();
    descController.dispose();
  }

  Future<void> _confirmDeleteContest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Delete Contest', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${contest.name}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ApiService.deleteContest(contest.id);
        widget.onRefresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmRemoveParticipant(ContestParticipant participant) async {
    final isSelf = participant.userId == _currentUserId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(isSelf ? 'Leave Contest' : 'Remove Participant', style: const TextStyle(color: Colors.white)),
        content: Text(
          isSelf ? 'Are you sure you want to leave "${contest.name}"?' : 'Remove ${participant.displayName} from this contest?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(isSelf ? 'Leave' : 'Remove', style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ApiService.removeParticipant(contest.id, participant.userId);
        widget.onRefresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnded = contest.isEnded;
    final hasStarted = contest.hasStarted;
    final isParticipant = !_isCreator && contest.participants.any((p) => p.userId == _currentUserId);

    final sortedParticipants = List<ContestParticipant>.from(contest.participants)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return Stack(
      children: [
        Card(
          color: const Color(0xFF161B22),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isEnded
                  ? const Color(0xFF3FB950).withOpacity(0.5)
                  : hasStarted
                      ? const Color(0xFF58A6FF).withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contest.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (!isEnded && _isCreator)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: const Icon(Icons.link, color: Color(0xFF58A6FF), size: 20),
                          tooltip: 'Copy Invite Link',
                          onPressed: () {
                            final link = 'https://app.rythmn.fit/invite/${contest.id}';
                            Clipboard.setData(ClipboardData(text: link));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invite link copied!')),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    if (_isCreator)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.5), size: 20),
                        color: const Color(0xFF21262D),
                        onSelected: (value) {
                          if (value == 'edit') _showRenameDialog();
                          if (value == 'delete') _confirmDeleteContest();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit Contest', style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 'delete', child: Text('Delete Contest', style: TextStyle(color: Colors.redAccent))),
                        ],
                      )
                    else if (isParticipant)
                      IconButton(
                        icon: Icon(Icons.logout, color: Colors.white.withOpacity(0.4), size: 18),
                        tooltip: 'Leave Contest',
                        onPressed: () {
                          final me = contest.participants.firstWhere((p) => p.userId == _currentUserId);
                          _confirmRemoveParticipant(me);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(isEnded, hasStarted),
                  ],
                ),
                if (contest.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    contest.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(contest.startDate)} - ${_formatDate(contest.endDate)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isEnded && sortedParticipants.isNotEmpty) ...[
                  _buildPodiumSection(sortedParticipants.take(3).toList()),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Leaderboard',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...sortedParticipants.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final participant = entry.value;
                  return _buildParticipantRow(rank, participant, isEnded);
                }),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isEnded, bool hasStarted) {
    Color bgColor;
    Color textColor;
    String text;

    if (isEnded) {
      bgColor = const Color(0xFF238636).withOpacity(0.2);
      textColor = const Color(0xFF3FB950);
      text = 'Ended';
    } else if (hasStarted) {
      bgColor = const Color(0xFF58A6FF).withOpacity(0.2);
      textColor = const Color(0xFF58A6FF);
      text = 'Active';
    } else {
      bgColor = const Color(0xFFF0883E).withOpacity(0.2);
      textColor = const Color(0xFFF0883E);
      text = 'Upcoming';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }


  Widget _buildPodiumSection(List<ContestParticipant> topThree) {
    const rankLabels = ['🥇 Winner', '🥈 2nd Place', '🥉 3rd Place'];
    const rankColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF238636).withOpacity(0.15),
            const Color(0xFF161B22),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF238636).withOpacity(0.3),
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
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Final Results',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topThree.asMap().entries.map((entry) {
            final rank = entry.key;
            final participant = entry.value;
            final color = rankColors[rank];
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: rank == 0 
                    ? color.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: rank == 0 
                    ? Border.all(color: color.withOpacity(0.4), width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  // User avatar
                  if (participant.userPhoto != null && participant.userPhoto!.isNotEmpty)
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(participant.userPhoto!),
                    )
                  else
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withOpacity(0.3),
                      child: Text(
                        participant.displayName.isNotEmpty 
                            ? participant.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rankLabels[rank],
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          participant.displayName,
                          style: TextStyle(
                            color: rank == 0 ? Colors.white : Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: rank == 0 ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${participant.totalScore} pts',
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildParticipantRow(int rank, ContestParticipant participant, bool isEnded) {
    Color? rankColor;
    if (isEnded) {
      if (rank == 1) rankColor = const Color(0xFFFFD700);
      if (rank == 2) rankColor = const Color(0xFFC0C0C0);
      if (rank == 3) rankColor = const Color(0xFFCD7F32);
    }

    final canRemove = _isCreator && participant.userId != _currentUserId && !isEnded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor?.withOpacity(0.2) ?? Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: rankColor ?? Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (participant.userPhoto != null && participant.userPhoto!.isNotEmpty)
            CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(participant.userPhoto!),
            )
          else
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white.withOpacity(0.1),
              child: Text(
                participant.displayName.isNotEmpty ? participant.displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              participant.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            '${participant.totalScore} pts',
            style: TextStyle(
              color: rankColor ?? const Color(0xFF58A6FF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canRemove)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InkWell(
                onTap: () => _confirmRemoveParticipant(participant),
                borderRadius: BorderRadius.circular(12),
                child: Icon(Icons.close, size: 16, color: Colors.white.withOpacity(0.3)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

class CreateContestDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const CreateContestDialog({super.key, required this.onCreated});

  @override
  State<CreateContestDialog> createState() => _CreateContestDialogState();
}

class _CreateContestDialogState extends State<CreateContestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoading = false;

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
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
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _createContest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUserId = AuthService.currentUser?.id ?? '';
      final contest = await ApiService.createContest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        creatorId: currentUserId,
        startDate: _startDate.toIso8601String().split('T')[0],
        endDate: DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toIso8601String(),
        userIds: [currentUserId],
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        _showInviteLinkDialog(context, contest.id, contest.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create contest: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInviteLinkDialog(BuildContext context, String contestId, String contestName) {
    final inviteLink = 'https://app.rythmn.fit/invite/$contestId';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF3FB950), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Contest Created!',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                contestName,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
              const SizedBox(height: 20),
              Text(
                'Share this link to invite friends:',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        inviteLink,
                        style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Color(0xFF58A6FF), size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite link copied!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFD700),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Create Contest',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Contest Name',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                  ),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDateSelector('Start', _startDate, () => _selectDate(true)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateSelector('End', _endDate, () => _selectDate(false)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createContest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Contest',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
