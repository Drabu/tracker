import 'package:flutter/material.dart';
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
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contests.length,
                    itemBuilder: (context, index) {
                      return ContestCard(
                        contest: _contests[index],
                        onRefresh: _loadContests,
                      );
                    },
                  ),
                ),
    );
  }
}

class ContestCard extends StatelessWidget {
  final Contest contest;
  final VoidCallback onRefresh;

  const ContestCard({
    super.key,
    required this.contest,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isEnded = contest.isEnded;
    final hasStarted = contest.hasStarted;
    
    final sortedParticipants = List<ContestParticipant>.from(contest.participants)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return Card(
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

  String _getFirstName(String fullName) {
    return fullName.split(' ').first;
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
                        _getFirstName(participant.userName).isNotEmpty 
                            ? _getFirstName(participant.userName)[0].toUpperCase()
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
                          _getFirstName(participant.userName),
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
                participant.userName.isNotEmpty ? participant.userName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _getFirstName(participant.userName),
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
  List<UserBasic> _allUsers = [];
  Set<String> _selectedUserIds = {};
  bool _isLoading = false;
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await ApiService.getAllUsers();
      setState(() {
        _allUsers = users;
        _isLoadingUsers = false;
        final currentUserId = AuthService.currentUser?.id;
        if (currentUserId != null) {
          _selectedUserIds.add(currentUserId);
        }
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
    }
  }

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
    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 participants')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.createContest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        creatorId: AuthService.currentUser?.id ?? '',
        startDate: _startDate.toIso8601String().split('T')[0],
        endDate: DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toIso8601String(),
        userIds: _selectedUserIds.toList(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
              Text(
                'Select Participants',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoadingUsers
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _allUsers.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No users found',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _allUsers.length,
                              itemBuilder: (context, index) {
                                final user = _allUsers[index];
                                final isSelected = _selectedUserIds.contains(user.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedUserIds.add(user.id);
                                      } else {
                                        _selectedUserIds.remove(user.id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    user.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    user.email,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                  secondary: user.photoUrl != null && user.photoUrl!.isNotEmpty
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(user.photoUrl!),
                                          radius: 18,
                                        )
                                      : CircleAvatar(
                                          backgroundColor: Colors.white.withOpacity(0.1),
                                          radius: 18,
                                          child: Text(
                                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                  activeColor: const Color(0xFF58A6FF),
                                  checkColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                );
                              },
                            ),
                ),
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
