import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kritun/features/trials/trial_service.dart';

import 'team_chat_screen.dart';
import 'team_info_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;

  const TeamDetailScreen({super.key, required this.teamId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  String teamName = "";
  bool loadingName = true;
  bool _deletingTeam = false;
  void _openEditTeamSheet(BuildContext context, Map<String, dynamic> team) {
    final nameController = TextEditingController(text: team['name'] ?? '');
    final tagController = TextEditingController(text: team['tag'] ?? '');
    final gameController = TextEditingController(text: team['gameName'] ?? '');
    final regionController = TextEditingController(text: team['region'] ?? '');
    final descController = TextEditingController(
      text: team['description'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool saving = false;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Edit team',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'Team name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tagController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Tag (optional, e.g. KR)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: gameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Game (e.g. Valorant)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: regionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Region (e.g. India, EU)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Team name cannot be empty'),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => saving = true);

                              try {
                                await FirebaseFirestore.instance
                                    .collection('teams')
                                    .doc(widget.teamId)
                                    .update({
                                      'name': name,
                                      'tag': tagController.text.trim(),
                                      'gameName': gameController.text.trim(),
                                      'region': regionController.text.trim(),
                                      'description': descController.text.trim(),
                                    });

                                if (mounted) {
                                  // update app bar title
                                  setState(() {
                                    teamName = name;
                                  });
                                }

                                if (Navigator.of(ctx).canPop()) {
                                  Navigator.of(ctx).pop();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to update team info',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                setModalState(() => saving = false);
                              }
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTeamName();
    void _openEditTeamSheet(BuildContext context, Map<String, dynamic> team) {
      final nameController = TextEditingController(text: team['name'] ?? '');
      final tagController = TextEditingController(text: team['tag'] ?? '');
      final gameController = TextEditingController(
        text: team['gameName'] ?? '',
      );
      final regionController = TextEditingController(
        text: team['region'] ?? '',
      );
      final descController = TextEditingController(
        text: team['description'] ?? '',
      );

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF121212),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          bool saving = false;

          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  top: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Edit team',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Team name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tagController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Tag (optional, e.g. KR)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: gameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Game (e.g. Valorant)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: regionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Region (e.g. India, EU)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Team name cannot be empty',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);

                                try {
                                  await FirebaseFirestore.instance
                                      .collection('teams')
                                      .doc(widget.teamId)
                                      .update({
                                        'name': name,
                                        'tag': tagController.text.trim(),
                                        'gameName': gameController.text.trim(),
                                        'region': regionController.text.trim(),
                                        'description': descController.text
                                            .trim(),
                                      });

                                  // update app bar title state
                                  if (mounted) {
                                    setState(() {
                                      teamName = name;
                                    });
                                  }

                                  if (context.mounted) Navigator.of(ctx).pop();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to update team info',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  setModalState(() => saving = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save changes',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  Future<void> _deleteTeam(BuildContext context) async {
    setState(() => _deletingTeam = true);

    final teamRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId);

    try {
      // 🔥 Delete some known subcollections (basic cleanup)
      for (final sub in ['members', 'joinRequests', 'vacancies', 'chat']) {
        final snap = await teamRef.collection(sub).get();
        for (final d in snap.docs) {
          await d.reference.delete();
        }
      }

      // Delete main team doc
      await teamRef.delete();

      if (!mounted) return;

      Navigator.of(context).pop(); // close TeamDetailScreen
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team deleted')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete team')));
      }
    } finally {
      if (mounted) {
        setState(() => _deletingTeam = false);
      }
    }
  }

  Future<void> _confirmDeleteTeam(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'Delete team?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently remove the team, its members list, '
          'vacancies and chat messages. This action cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTeam(context);
    }
  }

  Future<void> _loadTeamName() async {
    final doc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .get();

    setState(() {
      teamName = doc.data()?['name'] ?? "";
      loadingName = false;
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadTeam() {
    return FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream() {
    return FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('members')
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadUser(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  @override
  Widget build(BuildContext context) {
    final appTitle = loadingName
        ? 'Team'
        : (teamName.isEmpty ? 'Team' : teamName);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          appTitle,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Team info',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TeamInfoScreen(teamId: widget.teamId),
                ),
              );
            },
          ),
        ],
      ),

      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _loadTeam(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Team not found.',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final team = snapshot.data!.data()!;
          final name = team['name'] ?? 'Unnamed team';
          final tag = team['tag'] ?? '';
          final game = team['gameName'] ?? 'Any game';
          final region = team['region'] ?? 'Global';
          final desc = team['description'] ?? '';
          final ownerUid = team['ownerUid'] ?? '';
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final isOwner = currentUid != null && currentUid == ownerUid;

          final displayTitle = tag.toString().isNotEmpty
              ? '$name [$tag]'
              : name;

          final initial = name.toString().isNotEmpty
              ? name.toString()[0].toUpperCase()
              : '?';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= HEADER CARD =================
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _chipIconText(
                                  icon: Icons.sports_esports,
                                  label: game,
                                ),
                                _chipIconText(
                                  icon: Icons.public,
                                  label: region,
                                ),
                              ],
                            ),
                            if (desc.toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isOwner)
                        IconButton(
                          tooltip: 'Edit team',
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.white70,
                          ),
                          onPressed: () => _openEditTeamSheet(context, team),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ================= JOIN SECTION =================
                _sectionCard(
                  title: 'Join Team',
                  icon: Icons.group_add_outlined,
                  child: _JoinSection(
                    teamId: widget.teamId,
                    ownerUid: ownerUid,
                  ),
                ),

                const SizedBox(height: 16),

                // ================= OWNER JOIN REQUESTS =================
                if (isOwner)
                  _sectionCard(
                    title: 'Join Requests',
                    icon: Icons.inbox_outlined,
                    child: _OwnerJoinRequestsSection(teamId: widget.teamId),
                  ),

                if (isOwner) const SizedBox(height: 16),

                // ================= VACANCIES =================
                _sectionCard(
                  title: 'Vacancies',
                  icon: Icons.calendar_month_outlined,
                  child: _VacanciesSection(
                    teamId: widget.teamId,
                    isOwner: isOwner,
                    teamGameName: game,
                  ),
                ),

                const SizedBox(height: 16),

                // ================= MEMBERS =================
                _sectionCard(
                  title: 'Members',
                  icon: Icons.people_alt_outlined,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _membersStream(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      if (snap.hasError) {
                        return const Text(
                          'Error loading members.',
                          style: TextStyle(color: Colors.redAccent),
                        );
                      }

                      final docs = snap.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Text(
                          'No members yet.',
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      return Column(
                        children: docs.map((doc) {
                          final m = doc.data();
                          final uid = m['uid'] ?? '';
                          final role = m['role'] ?? 'Member';

                          return FutureBuilder<
                            DocumentSnapshot<Map<String, dynamic>>
                          >(
                            future: _loadUser(uid),
                            builder: (context, userSnap) {
                              String title = 'User: $uid';
                              String subtitle = 'Role: $role';

                              if (userSnap.connectionState ==
                                      ConnectionState.done &&
                                  userSnap.hasData &&
                                  userSnap.data!.exists) {
                                final u = userSnap.data!.data()!;
                                final username = u['username'] ?? uid;
                                final email = u['email'] ?? '';

                                title = username;
                                subtitle = email.isNotEmpty
                                    ? 'Role: $role · $email'
                                    : 'Role: $role';
                              }

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                trailing: isOwner
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.sports_esports,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          try {
                                            await TrialService.createTrial(
                                              targetUserUid: uid,
                                              game: game,
                                              teamId: widget.teamId,
                                              notes: 'Trial from team $tag',
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Trial created',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Failed to create trial',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      )
                                    : null,
                              );
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                // ================= DANGER ZONE: DELETE TEAM =================
                if (isOwner) ...[
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Danger zone',
                    icon: Icons.warning_amber_outlined,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _deletingTeam
                            ? null
                            : () => _confirmDeleteTeam(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 1,
                          ),
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _deletingTeam
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline, size: 18),
                        label: const Text(
                          'Delete team',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Small helper: chip style for game/region
Widget _chipIconText({required IconData icon, required String label}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
  );
}

// Small helper: standard section card container
Widget _sectionCard({
  required String title,
  required IconData icon,
  Widget? trailing,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: const Color(0xFF121212),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[400]),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

// ==========================================
// JOIN SECTION
// ==========================================

class _JoinStatus {
  final bool isOwner;
  final bool isMember;
  final bool hasPendingRequest;

  const _JoinStatus({
    this.isOwner = false,
    this.isMember = false,
    this.hasPendingRequest = false,
  });
}

class _JoinSection extends StatefulWidget {
  final String teamId;
  final String ownerUid;

  const _JoinSection({super.key, required this.teamId, required this.ownerUid});

  @override
  State<_JoinSection> createState() => _JoinSectionState();
}

class _JoinSectionState extends State<_JoinSection> {
  bool _isSending = false;
  String? _statusText;

  Future<_JoinStatus> _getStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _JoinStatus();
    final uid = user.uid;

    if (uid == widget.ownerUid) {
      return const _JoinStatus(isOwner: true);
    }

    final teamRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId);

    if ((await teamRef.collection('members').doc(uid).get()).exists) {
      return const _JoinStatus(isMember: true);
    }

    final pending = await teamRef
        .collection('joinRequests')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (pending.docs.isNotEmpty) {
      return const _JoinStatus(hasPendingRequest: true);
    }

    return const _JoinStatus();
  }

  Future<void> _sendRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
      _statusText = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('joinRequests')
          .add({
            'uid': user.uid,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

      setState(() => _statusText = 'Join request sent.');
    } catch (e) {
      setState(() => _statusText = 'Failed to send request.');
    }

    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_JoinStatus>(
      future: _getStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final st = snapshot.data!;

        // helper to show a disabled status button
        Widget _statusButton(String label) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                disabledForegroundColor: Colors.grey[400],
                side: BorderSide(color: Colors.grey[700]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        }

        if (st.isOwner) {
          return _statusButton('You own this team');
        }
        if (st.isMember) {
          return _statusButton('You are a member');
        }
        if (st.hasPendingRequest) {
          return _statusButton('Join request pending');
        }

        // normal visible join button
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSending ? null : _sendRequest,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  backgroundColor: Colors.blueAccent,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Request to Join',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            if (_statusText != null) ...[
              const SizedBox(height: 6),
              Text(
                _statusText!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ==========================================
// OWNER JOIN REQUESTS
// ==========================================

class _OwnerJoinRequestsSection extends StatelessWidget {
  final String teamId;

  const _OwnerJoinRequestsSection({super.key, required this.teamId});

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingRequests() {
    return FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('joinRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadUser(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  Future<void> _accept(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> req,
  ) async {
    final uid = req['uid'];
    if (uid == null) return;

    final teamRef = FirebaseFirestore.instance.collection('teams').doc(teamId);

    final batch = FirebaseFirestore.instance.batch();

    batch.set(teamRef.collection('members').doc(uid), {
      'uid': uid,
      'role': 'Player',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.update(teamRef, {
      'memberUids': FieldValue.arrayUnion([uid]),
    });

    batch.update(req.reference, {
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Accepted')));
  }

  Future<void> _reject(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> req,
  ) async {
    await req.reference.update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rejected')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingRequests(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Text(
            'No pending requests',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: docs.map((d) {
            final uid = d['uid'];

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _loadUser(uid),
              builder: (context, userSnap) {
                String title = uid;
                if (userSnap.hasData && userSnap.data!.exists) {
                  title = userSnap.data!.data()!['username'] ?? uid;
                }

                return Card(
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    dense: true,
                    title: Text(title, style: const TextStyle(fontSize: 14)),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Reject',
                          icon: const Icon(
                            Icons.close,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => _reject(context, d),
                        ),
                        IconButton(
                          tooltip: 'Accept',
                          icon: const Icon(
                            Icons.check,
                            color: Colors.greenAccent,
                            size: 20,
                          ),
                          onPressed: () => _accept(context, d),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

// ==========================================
// VACANCIES
// ==========================================

class _VacanciesSection extends StatelessWidget {
  final String teamId;
  final bool isOwner;
  final String teamGameName;

  const _VacanciesSection({
    super.key,
    required this.teamId,
    required this.isOwner,
    required this.teamGameName,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('vacancies')
        .snapshots();
  }

  void _openCreate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: _CreateVacancySheet(
          teamId: teamId,
          defaultGameName: teamGameName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No open vacancies.',
                style: TextStyle(color: Colors.grey),
              ),
              if (isOwner) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openCreate(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create vacancy'),
                ),
              ],
            ],
          );
        }

        final uid = FirebaseAuth.instance.currentUser?.uid;

        return Column(
          children: [
            if (isOwner)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _openCreate(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create vacancy'),
                ),
              ),
            if (isOwner) const SizedBox(height: 8),
            ...docs.map((doc) {
              final v = doc.data();

              final isOpen = v['isOpen'] == true;
              final statusLabel = isOpen ? 'Open' : 'Closed';
              final statusColor = isOpen
                  ? Colors.greenAccent
                  : Colors.redAccent;

              return Card(
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              v['title'] ?? 'Vacancy',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                              ),
                            ),
                          ),
                          if (isOwner)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => doc.reference.delete(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Game: ${v['gameName'] ?? teamGameName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if ((v['role'] ?? '').toString().isNotEmpty)
                        Text(
                          'Role: ${v['role']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      if ((v['rankMin'] ?? '').toString().isNotEmpty ||
                          (v['rankMax'] ?? '').toString().isNotEmpty)
                        Text(
                          'Rank: ${v['rankMin'] ?? ''} - ${v['rankMax'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      if ((v['description'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            v['description'],
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (!isOwner && uid != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: _VacancyApplyButton(
                            teamId: teamId,
                            vacancyId: doc.id,
                            isOpen: isOpen,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

// ==========================================
// VACANCY CREATION SHEET
// ==========================================

class _CreateVacancySheet extends StatefulWidget {
  final String teamId;
  final String defaultGameName;

  const _CreateVacancySheet({
    super.key,
    required this.teamId,
    required this.defaultGameName,
  });

  @override
  State<_CreateVacancySheet> createState() => _CreateVacancySheetState();
}

class _CreateVacancySheetState extends State<_CreateVacancySheet> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _role = TextEditingController();
  final _game = TextEditingController();
  final _rankMin = TextEditingController();
  final _rankMax = TextEditingController();
  final _desc = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _game.text = widget.defaultGameName;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ref = FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('vacancies')
          .doc();

      await ref.set({
        'id': ref.id,
        'title': _title.text.trim(),
        'role': _role.text.trim(),
        'gameName': _game.text.trim(),
        'rankMin': _rankMin.text.trim(),
        'rankMax': _rankMax.text.trim(),
        'description': _desc.text.trim(),
        'isOpen': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = "Failed to create vacancy.");
    }

    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Vacancy',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(hintText: 'Title'),
                validator: (v) =>
                    v!.trim().isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _role,
                decoration: const InputDecoration(
                  hintText: 'Role (e.g. IGL, Entry)',
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _game,
                decoration: const InputDecoration(
                  hintText: 'Game (e.g. Valorant)',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rankMin,
                      decoration: const InputDecoration(hintText: 'Min Rank'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _rankMax,
                      decoration: const InputDecoration(hintText: 'Max Rank'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Description'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// APPLY BUTTON
// ==========================================

class _VacancyApplyButton extends StatefulWidget {
  final String teamId;
  final String vacancyId;
  final bool isOpen;

  const _VacancyApplyButton({
    super.key,
    required this.teamId,
    required this.vacancyId,
    required this.isOpen,
  });

  @override
  State<_VacancyApplyButton> createState() => _VacancyApplyButtonState();
}

class _VacancyApplyButtonState extends State<_VacancyApplyButton> {
  bool _sending = false;
  String? _status;

  Future<bool> _hasApplied() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final existing = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('vacancies')
        .doc(widget.vacancyId)
        .collection('applications')
        .where('uid', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'accepted'])
        .limit(1)
        .get();

    return existing.docs.isNotEmpty;
  }

  Future<void> _apply() async {
    if (!widget.isOpen) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _sending = true);

    try {
      final apps = FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('vacancies')
          .doc(widget.vacancyId)
          .collection('applications');

      await apps.add({
        'uid': user.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _status = "Applied");
    } catch (e) {
      setState(() => _status = "Failed");
    }

    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) {
      return const Text(
        "Closed",
        style: TextStyle(color: Colors.redAccent, fontSize: 12),
      );
    }

    return FutureBuilder<bool>(
      future: _hasApplied(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (snap.data == true || _status == "Applied") {
          return const Text(
            "Applied",
            style: TextStyle(color: Colors.greenAccent, fontSize: 12),
          );
        }

        if (_status == "Failed") {
          return const Text(
            "Failed",
            style: TextStyle(color: Colors.redAccent, fontSize: 12),
          );
        }

        return IconButton(
          icon: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward, size: 20),
          onPressed: _sending ? null : _apply,
        );
      },
    );
  }
}
