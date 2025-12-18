import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kritun/features/trials/trial_service.dart';

import 'team_detail_screen.dart';
import 'player_profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // update hint text
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _allTeamsStream() {
    return FirebaseFirestore.instance.collection('teams').limit(50).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _playersStream() {
    return FirebaseFirestore.instance.collection('users').limit(50).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isTeamsTab = _tabController.index == 0;
    final hintText = isTeamsTab ? 'Search teams...' : 'Search players...';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Discover',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Teams'),
            Tab(text: 'Players'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF121212),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ================== TEAMS TAB ==================
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _allTeamsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Error loading teams.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    final query = _searchQuery;
                    final filteredDocs = query.isEmpty
                        ? docs
                        : docs.where((doc) {
                            final data = doc.data();
                            final name = (data['name'] ?? '')
                                .toString()
                                .toLowerCase();
                            final tag = (data['tag'] ?? '')
                                .toString()
                                .toLowerCase();
                            final game = (data['gameName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final region = (data['region'] ?? '')
                                .toString()
                                .toLowerCase();
                            final desc = (data['description'] ?? '')
                                .toString()
                                .toLowerCase();

                            return name.contains(query) ||
                                tag.contains(query) ||
                                game.contains(query) ||
                                region.contains(query) ||
                                desc.contains(query);
                          }).toList();

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No teams found yet.\nCreate one from the Teams tab!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No matching teams.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final team = doc.data();
                        final name = team['name'] ?? 'Unnamed team';
                        final tag = team['tag'] ?? '';
                        final game = team['gameName'] ?? 'Any game';
                        final region = team['region'] ?? 'Global';
                        final desc = team['description'] ?? '';

                        final displayName = tag.toString().isNotEmpty
                            ? '$name [$tag]'
                            : name;

                        return Card(
                          color: const Color(0xFF121212),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[800],
                              child: Text(
                                name.toString().isNotEmpty
                                    ? name.toString()[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  "Game: $game",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  "Region: $region",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (desc.toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TeamDetailScreen(teamId: doc.id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),

                // ================== PLAYERS TAB ==================
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _playersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Error loading players.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No players found yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    final query = _searchQuery;

                    final filteredDocs = docs.where((doc) {
                      final data = doc.data();
                      final uid = doc.id;

                      if (uid == currentUid) return false;
                      if (query.isEmpty) return true;

                      final username = (data['username'] ?? '')
                          .toString()
                          .toLowerCase();
                      final email = (data['email'] ?? '')
                          .toString()
                          .toLowerCase();
                      final mainGame = (data['mainGame'] ?? '')
                          .toString()
                          .toLowerCase();

                      return username.contains(query) ||
                          email.contains(query) ||
                          mainGame.contains(query);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No matching players.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final userDoc = filteredDocs[index];
                        final data = userDoc.data();
                        final uid = userDoc.id;

                        final username = data['username'] ?? 'Unknown player';
                        final email = data['email'] ?? '';
                        final mainGame = data['mainGame'] ?? '';
                        final avatarUrl = (data['avatarUrl'] ?? '').toString();

                        return Card(
                          color: const Color(0xFF121212),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(Icons.person, size: 20)
                                  : null,
                            ),
                            title: Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (email.toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                                if (mainGame.toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'Main game: $mainGame',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                try {
                                  await TrialService.createTrial(
                                    targetUserUid: uid,
                                    game: mainGame.toString().isNotEmpty
                                        ? mainGame
                                        : null,
                                    teamId: null,
                                    notes: null,
                                  );

                                  // ignore: use_build_context_synchronously
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Trial invite sent to $username',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  // ignore: use_build_context_synchronously
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to send trial: $e'),
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Trial',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlayerProfileScreen(userId: uid),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
