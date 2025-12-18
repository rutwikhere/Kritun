import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kritun/features/home/presentation/krit_detail_screen.dart';
import 'package:kritun/features/messages/presentation/direct_chat_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String userId;

  const PlayerProfileScreen({super.key, required this.userId});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // ------------------------------------------------
  //              CONNECTION STATE / ACTIONS
  // ------------------------------------------------

  Stream<DocumentSnapshot<Map<String, dynamic>>> _connectionStream() {
    // from my (current user) perspective
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('connections')
        .doc(widget.userId)
        .snapshots();
  }

  Future<void> _sendConnectionRequest() async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      final meRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('connections')
          .doc(widget.userId);

      final otherRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('connections')
          .doc(currentUid);

      batch.set(meRef, {
        'uid': widget.userId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(otherRef, {
        'uid': currentUid,
        'status': 'requested',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Connection request sent")));
    } catch (e) {
      debugPrint("Connection error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to send request")));
    }
  }

  Future<void> _acceptConnectionRequest() async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      final meRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('connections')
          .doc(widget.userId);

      final otherRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('connections')
          .doc(currentUid);

      batch.set(meRef, {
        'uid': widget.userId,
        'status': 'connected',
        'connectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(otherRef, {
        'uid': currentUid,
        'status': 'connected',
        'connectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Connection accepted")));
    } catch (e) {
      debugPrint("Accept connection error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to accept request")));
    }
  }

  Future<void> _rejectConnectionRequest() async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      final meRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('connections')
          .doc(widget.userId);

      final otherRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('connections')
          .doc(currentUid);

      batch.delete(meRef);
      batch.delete(otherRef);

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Request rejected")));
    } catch (e) {
      debugPrint("Reject connection error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to reject request")));
    }
  }

  Future<void> _openChat() async {
    final chatId = _generateChatId(currentUid, widget.userId);

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final exists = await chatRef.get();
    if (!exists.exists) {
      await chatRef.set({
        'chatId': chatId,
        'participants': [currentUid, widget.userId],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DirectChatScreen(chatId: chatId, otherUserId: widget.userId),
      ),
    );
  }

  String _generateChatId(String a, String b) {
    final list = [a, b]..sort();
    return list.join('_');
  }

  // ------------------------------------------------
  //                    DATA STREAMS
  // ------------------------------------------------

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _userKritsStream() {
    return FirebaseFirestore.instance
        .collection('krits')
        .where('authorUid', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _gameProfilesStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('gameProfiles')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _userTeamsStream() {
    return FirebaseFirestore.instance
        .collection('teams')
        .where('memberUids', arrayContains: widget.userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _trialsStream() {
    return FirebaseFirestore.instance
        .collection('trials')
        .where('targetUid', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _userConnectionsStream() {
    // only fully connected ones
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('connections')
        .where('status', isEqualTo: 'connected')
        .snapshots();
  }

  // Small stat item (Posts / Connections / Teams)
  Widget _statItem({required String label, required int value}) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // ==========================================================
  //                           UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Profile not found"));
          }

          final data = snapshot.data!.data()!;
          final username = (data['username'] ?? 'Unknown').toString();
          final email = (data['email'] ?? '').toString();
          final avatarUrl = (data['avatarUrl'] ?? '').toString();
          final createdAt = data['createdAt']?.toDate();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ========== HEADER: avatar + stats row ==========
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? const Icon(Icons.person, size: 36)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _userKritsStream(),
                              builder: (context, snap) {
                                final count = snap.data?.docs.length ?? 0;
                                return _statItem(label: 'Posts', value: count);
                              },
                            ),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _userConnectionsStream(),
                              builder: (context, snap) {
                                final count = snap.data?.docs.length ?? 0;
                                return _statItem(
                                  label: 'Connections',
                                  value: count,
                                );
                              },
                            ),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _userTeamsStream(),
                              builder: (context, snap) {
                                final count = snap.data?.docs.length ?? 0;
                                return _statItem(label: 'Teams', value: count);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // username + email + joined date
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Joined ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // ========== CONNECT / MESSAGE buttons ==========
                  if (widget.userId != currentUid)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _connectionStream(),
                      builder: (context, snap) {
                        final conn = snap.data?.data();
                        final String? status = conn?['status'];

                        Widget buttons;

                        if (status == 'connected') {
                          buttons = Row(
                            children: [
                              Expanded(
                                child: _solidButton(
                                  "Connected",
                                  null,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _solidButton(
                                  "Message",
                                  _openChat,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          );
                        } else if (status == 'pending') {
                          buttons = Row(
                            children: [
                              Expanded(
                                child: _solidButton(
                                  "Request Sent",
                                  null,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _solidButton(
                                  "Message",
                                  null,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          );
                        } else if (status == 'requested') {
                          buttons = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _solidButton(
                                      "Accept",
                                      _acceptConnectionRequest,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _solidButton(
                                      "Reject",
                                      _rejectConnectionRequest,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _solidButton(
                                "Message",
                                null,
                                color: Colors.grey.shade800,
                              ),
                            ],
                          );
                        } else {
                          buttons = Row(
                            children: [
                              Expanded(
                                child: _solidButton(
                                  "Connect",
                                  _sendConnectionRequest,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _solidButton(
                                  "Message",
                                  null,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          );
                        }

                        return buttons;
                      },
                    ),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 16),

                  // ========== Performance (Trials) ==========
                  _buildTrialSection(),

                  const SizedBox(height: 18),

                  // ========== Game Profiles (horizontal like highlights) ==========
                  _buildGameProfiles(),

                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 12),

                  // ========== Posts grid ==========
                  _buildUserPosts(),

                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 12),

                  // ========== Teams ==========
                  _buildTeams(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  //                      SECTION HELPERS
  // ==========================================================

  Widget _solidButton(
    String text,
    VoidCallback? onTap, {
    Color? color = Colors.blueAccent,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTrialSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              "Performance",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              "(Trials)",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _trialsStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snap.hasError) {
              return const Text(
                "Error loading trials.",
                style: TextStyle(color: Colors.redAccent),
              );
            }

            final docs = snap.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Text(
                "No trials played yet.",
                style: TextStyle(color: Colors.grey),
              );
            }

            double sumRatings = 0;
            int count = 0;
            DateTime? latest;

            for (final d in docs) {
              final data = d.data();
              final rating = (data['rating'] ?? 0).toDouble();
              sumRatings += rating;
              count++;

              final ts = data['createdAt'];
              if (ts != null && ts is Timestamp) {
                final dt = ts.toDate();
                if (latest == null || dt.isAfter(latest!)) {
                  latest = dt;
                }
              }
            }

            final avg = sumRatings / count;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Average Rating",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        avg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Trials Played",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$count",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (latest != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Last: ${latest!.day}/${latest!.month}/${latest!.year}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGameProfiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Game Profiles",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _gameProfilesStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snap.hasError) {
              return const Text(
                "Error loading game profiles.",
                style: TextStyle(color: Colors.redAccent),
              );
            }

            final docs = snap.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Text(
                "No game profiles yet.",
                style: TextStyle(color: Colors.grey),
              );
            }

            return SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final g = docs[index].data();

                  final gameName = (g['gameName'] ?? 'Unknown game').toString();
                  final inGameId = (g['inGameId'] ?? '').toString();
                  final region = (g['region'] ?? '').toString();
                  final role = (g['primaryRole'] ?? '').toString();
                  final currentRank = (g['currentRank'] ?? '').toString();
                  final peakRank = (g['peakRank'] ?? '').toString();

                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFF111111),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              gameName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (inGameId.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      "In-game ID: $inGameId",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (region.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      "Region: $region",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (role.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      "Primary role: $role",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (currentRank.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      "Current rank: $currentRank",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (peakRank.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      "Peak rank: $peakRank",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text("Close"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            gameName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (currentRank.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                "Rank: $currentRank",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          if (region.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                region,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUserPosts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Posts",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _userKritsStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snap.hasError) {
              return const Text(
                "Error loading posts.",
                style: TextStyle(color: Colors.redAccent),
              );
            }

            final docs = snap.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Text(
                "No posts yet.",
                style: TextStyle(color: Colors.grey),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 1,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final mediaUrl = (data['mediaUrl'] ?? '').toString();
                final mediaType = (data['mediaType'] ?? 'none').toString();
                final text = (data['text'] ?? '').toString();

                Widget child;

                if (mediaType == 'image' && mediaUrl.isNotEmpty) {
                  child = ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(
                      mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  );
                } else if (mediaType == 'video' && mediaUrl.isNotEmpty) {
                  child = ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: _VideoGridThumb(url: mediaUrl),
                  );
                } else {
                  child = Container(
                    color: Colors.grey[900],
                    padding: const EdgeInsets.all(6),
                    child: Center(
                      child: Text(
                        text.isNotEmpty ? text : "No media",
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KritDetailScreen(kritId: doc.id),
                      ),
                    );
                  },
                  child: child,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTeams() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Teams",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _userTeamsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return const Text(
                "Error loading teams.",
                style: TextStyle(color: Colors.redAccent),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Text(
                "No teams yet.",
                style: TextStyle(color: Colors.grey),
              );
            }

            return Column(
              children: docs.map((doc) {
                final t = doc.data();
                final name = (t['name'] ?? 'Unnamed team').toString();
                final game = (t['gameName'] ?? 'Any game').toString();
                final region = (t['region'] ?? 'Global').toString();

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Game: $game · Region: $region",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ======================================================
//                  VIDEO THUMBNAIL WIDGET
// ======================================================

class _VideoGridThumb extends StatelessWidget {
  final String url;
  const _VideoGridThumb({required this.url});

  Future<Uint8List?> _generateThumb() {
    return VideoThumbnail.thumbnailData(
      video: url,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 400,
      quality: 75,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _generateThumb(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return Container(
            color: Colors.black12,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black),
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 32,
                  color: Colors.white70,
                ),
              ),
            ],
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            const Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.play_circle_fill,
                size: 32,
                color: Colors.white70,
              ),
            ),
          ],
        );
      },
    );
  }
}
