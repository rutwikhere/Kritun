import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'trial_service.dart';

class MyTrialsScreen extends StatelessWidget {
  const MyTrialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in to see your trials.')),
      );
    }

    final uid = currentUser.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trials'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'As Player'),
              Tab(text: 'As Owner'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TrialsList(
              stream: TrialService.trialsForPlayer(uid),
              isOwnerView: false,
            ),
            _TrialsList(
              stream: TrialService.trialsForOwner(uid),
              isOwnerView: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialsList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool isOwnerView;

  const _TrialsList({required this.stream, required this.isOwnerView});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error loading trials.'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text(
              isOwnerView
                  ? 'You have not created any trials yet.'
                  : 'No trials assigned to you yet.',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final ownerUid = data['ownerUid'] as String;
            final targetUid = data['targetUid'] as String;

            final trialId = docs[index].id;
            final game = (data['game'] ?? '') as String;
            final notes = (data['notes'] ?? '') as String;
            final status = (data['status'] ?? 'pending') as String;
            final result = (data['result'] ?? '') as String?;
            final rating = data['rating'];
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            return Card(
              color: Colors.grey[900],
              child: ListTile(
                title: Text(
                  game.isEmpty ? 'Trial' : 'Trial – $game',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 👤 SHOW WHO THE TRIAL IS WITH
                    if (isOwnerView)
                      _UserMiniTile(userId: targetUid, label: 'To')
                    else
                      _UserMiniTile(userId: ownerUid, label: 'From'),

                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(notes),
                    ],

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        _StatusChip(status: status, result: result),
                        const SizedBox(width: 8),
                        if (rating is int)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$rating/5',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),

                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),

                onTap: isOwnerView
                    ? () {
                        _openResultSheet(context, trialId, data);
                      }
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  static String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _openResultSheet(
    BuildContext context,
    String trialId,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _TrialResultSheet(
        trialId: trialId,
        initialRating: (data['rating'] as int?) ?? 3,
        initialResult: (data['result'] as String?) ?? 'pass',
        initialFeedback: (data['feedback'] as String?) ?? '',
      ),
    );
  }
}

class _UserMiniTile extends StatelessWidget {
  final String userId;
  final String label;

  const _UserMiniTile({required this.userId, required this.label});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!.data();
        if (data == null) return const SizedBox();

        final username = data['username'] ?? 'Unknown';
        final avatarUrl = (data['avatarUrl'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey[800],
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 14)
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                '$label @$username',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final String? result;

  const _StatusChip({required this.status, required this.result});

  Color get _color {
    if (status == 'completed') {
      if (result == 'pass') return Colors.greenAccent;
      if (result == 'fail') return Colors.redAccent;
    }
    return Colors.orangeAccent;
  }

  String get _label {
    if (status == 'completed') {
      if (result == 'pass') return 'Passed';
      if (result == 'fail') return 'Failed';
      return 'Completed';
    }
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _color.withOpacity(0.2),
        border: Border.all(color: _color),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TrialResultSheet extends StatefulWidget {
  final String trialId;
  final int initialRating;
  final String initialResult;
  final String initialFeedback;

  const _TrialResultSheet({
    required this.trialId,
    required this.initialRating,
    required this.initialResult,
    required this.initialFeedback,
  });

  @override
  State<_TrialResultSheet> createState() => _TrialResultSheetState();
}

class _TrialResultSheetState extends State<_TrialResultSheet> {
  late int _rating;
  late String _result;
  late TextEditingController _feedbackController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _result = widget.initialResult;
    _feedbackController = TextEditingController(text: widget.initialFeedback);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await TrialService.updateTrialResult(
        trialId: widget.trialId,
        rating: _rating,
        result: _result,
        feedback: _feedbackController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save trial result')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Trial Result',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Rating'),
            const SizedBox(height: 4),
            Row(
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    Icons.star,
                    color: starIndex <= _rating ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = starIndex;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            const Text('Result'),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Pass'),
                  selected: _result == 'pass',
                  onSelected: (_) => setState(() => _result = 'pass'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Fail'),
                  selected: _result == 'fail',
                  onSelected: (_) => setState(() => _result = 'fail'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Feedback (optional)'),
            const SizedBox(height: 4),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Short feedback on the trial',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
