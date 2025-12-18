// feed_screen_updated.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:rxdart/rxdart.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

// remove duplicate imports & video_player (images only)
// keep your app imports (player_profile_screen, dm_list_screen) as needed

import 'package:kritun/features/home/presentation/player_profile_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _kritsStream() {
    return FirebaseFirestore.instance
        .collection('krits')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<List<MapEntry<String, List<_StoryData>>>> _sortStoriesByViewed(
    List<MapEntry<String, List<_StoryData>>> others,
  ) async {
    final unviewed = <MapEntry<String, List<_StoryData>>>[];
    final viewed = <MapEntry<String, List<_StoryData>>>[];

    for (final e in others) {
      final isViewed = await _isStoryViewedOnce(e.key);
      if (isViewed) {
        viewed.add(e);
      } else {
        unviewed.add(e);
      }
    }

    return [...unviewed, ...viewed];
  }

  Stream<bool> _isStoryViewedStream(String authorUid) {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Your own story is always pink
    if (currentUser == null || currentUser.uid == authorUid) {
      return Stream.value(false);
    }

    final viewsDoc = FirebaseFirestore.instance
        .collection('storyViews')
        .doc('${currentUser.uid}_$authorUid')
        .snapshots();

    final storiesQuery = FirebaseFirestore.instance
        .collection('stories')
        .where('authorUid', isEqualTo: authorUid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();

    return Rx.combineLatest2(viewsDoc, storiesQuery, (
      DocumentSnapshot viewDoc,
      QuerySnapshot<Map<String, dynamic>> storySnap,
    ) {
      // No stories → nothing to view
      if (storySnap.docs.isEmpty) return false;

      final latestStoryCreatedAt =
          (storySnap.docs.first['createdAt'] as Timestamp).toDate();

      // Never viewed before
      if (!viewDoc.exists) return false;

      final viewedAt = (viewDoc['viewedAt'] as Timestamp?)?.toDate();

      // ⏳ serverTimestamp not resolved yet → still viewed
      if (viewedAt == null) return true;

      // ✅ TRUE means GREY
      return viewedAt.isAfter(latestStoryCreatedAt) ||
          viewedAt.isAtSameMomentAs(latestStoryCreatedAt);
    });
  }

  Future<bool> _isStoryViewedOnce(String authorUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid == authorUid) {
      return false;
    }

    final viewDoc = await FirebaseFirestore.instance
        .collection('storyViews')
        .doc('${currentUser.uid}_$authorUid')
        .get();

    if (!viewDoc.exists) return false;

    final viewedAt = (viewDoc['viewedAt'] as Timestamp?)?.toDate();
    if (viewedAt == null) return true;

    final latestStorySnap = await FirebaseFirestore.instance
        .collection('stories')
        .where('authorUid', isEqualTo: authorUid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (latestStorySnap.docs.isEmpty) return false;

    final latestCreatedAt =
        (latestStorySnap.docs.first['createdAt'] as Timestamp).toDate();

    return viewedAt.isAfter(latestCreatedAt) ||
        viewedAt.isAtSameMomentAs(latestCreatedAt);
  }

  Future<int> _firstUnviewedIndex(
    String authorUid,
    List<_StoryData> stories,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Own story → always start from beginning
    if (currentUser == null || currentUser.uid == authorUid) {
      return 0;
    }

    final viewDoc = await FirebaseFirestore.instance
        .collection('storyViews')
        .doc('${currentUser.uid}_$authorUid')
        .get();

    if (!viewDoc.exists) return 0;

    final viewedAt = (viewDoc['viewedAt'] as Timestamp?)?.toDate();
    if (viewedAt == null) return 0;

    // Find first story newer than viewedAt
    for (int i = 0; i < stories.length; i++) {
      if (stories[i].createdAt.isAfter(viewedAt)) {
        return i;
      }
    }

    // All viewed → start from beginning
    return 0;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _storiesStream() {
    return FirebaseFirestore.instance
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots();
  }

  void _openCreateKritSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
          ),
          child: const _CreateKritSheet(),
        );
      },
    );
  }

  void _openCreateStorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
          ),
          child: const _CreateStorySheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Kritun',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          if (currentUser == null)
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log in to see notifications')),
                );
              },
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('connections')
                  .where('status', isEqualTo: 'requested')
                  .snapshots(),
              builder: (context, snapshot) {
                int requestCount = 0;
                if (snapshot.hasData) {
                  requestCount = snapshot.data!.docs.length;
                }

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    if (requestCount > 0)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              requestCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Material(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _openCreateKritSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.pinkAccent, Colors.orangeAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Create krit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _kritsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading feed.'));
          }

          final docs = snapshot.data?.docs ?? [];
          final currentUser = FirebaseAuth.instance.currentUser;

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    SizedBox(
                      height: 100,
                      child: currentUser == null
                          ? _buildStoriesLoggedOut(context)
                          : _buildStoriesLoggedIn(context, currentUser),
                    ),
                    Divider(height: 0.5, color: Colors.grey[850]),
                  ],
                );
              }

              final data = docs[index - 1].data();
              final kritId = docs[index - 1].id;

              return _buildKritPost(context, data, kritId);
            },
          );
        },
      ),
    );
  }

  Widget _buildStoriesLoggedOut(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _storiesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No stories yet', style: TextStyle(color: Colors.grey)),
          );
        }

        final Map<String, List<_StoryData>> storiesByUser = {};
        final Map<String, Map<String, dynamic>> userMeta = {};

        for (final doc in docs) {
          final d = doc.data();
          final uid = (d['authorUid'] ?? '').toString();
          if (uid.isEmpty) continue;

          userMeta[uid] = {
            'username': d['authorUsername'] ?? 'Unknown',
            'avatarUrl': d['authorAvatarUrl'] ?? '',
          };

          storiesByUser.putIfAbsent(uid, () => []);
          storiesByUser[uid]!.add(
            _StoryData(
              id: doc.id,
              mediaUrl: d['mediaUrl'],
              mediaType: d['mediaType'],
              createdAt: (d['createdAt'] as Timestamp).toDate(),
            ),
          );
        }

        final entries = storiesByUser.entries.toList();

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            final meta = userMeta[e.key]!;

            return StreamBuilder<bool>(
              stream: _isStoryViewedStream(e.key), // author UID
              builder: (context, snap) {
                final isViewed = snap.data ?? false;

                return _StoryCircle(
                  username: meta['username'],
                  avatarUrl: meta['avatarUrl'],
                  hasPlus: false,
                  isViewed: isViewed, // ✅ REQUIRED
                  onTapAvatar: () async {
                    final index = await _firstUnviewedIndex(e.key, e.value);

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _StoryViewerScreen(
                          userId: e.key,
                          username: meta['username'],
                          avatarUrl: meta['avatarUrl'],
                          stories: e.value,
                          initialIndex: index, // 🔥 AUTO-OPEN FIRST UNVIEWED
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildKritPost(
    BuildContext context,
    Map<String, dynamic> data,
    String kritId,
  ) {
    final text = data['text'] ?? '';
    final authorName = data['authorUsername'] ?? 'Unknown';
    final authorUid = (data['authorUid'] ?? '').toString();
    final avatarUrl = (data['authorAvatarUrl'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final gameTag = data['game'] ?? '';
    final mediaUrl = data['mediaUrl'] ?? '';
    final mediaType = data['mediaType'] ?? 'none';
    final likeCount = (data['likeCount'] ?? 0) as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerProfileScreen(userId: authorUid),
                    ),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      authorName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (mediaUrl.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KritLikeController(
                kritId: kritId,
                initialCount: likeCount,
                commentCount: (data['commentCount'] ?? 0) as int,
                mediaUrl: mediaUrl,
                mediaType: mediaType,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty)
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const TextSpan(text: '  '),
                            TextSpan(
                              text: text,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),

                    if (gameTag.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '#$gameTag',
                          style: const TextStyle(color: Colors.blueAccent),
                        ),
                      ),

                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _timeAgo(createdAt),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

        Divider(height: 0.5, color: Colors.grey[900]),
      ],
    );
  }

  Widget _buildStoriesLoggedIn(BuildContext context, User currentUser) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _storiesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final myUid = currentUser.uid;

        final Map<String, List<_StoryData>> storiesByUser = {};
        final Map<String, Map<String, dynamic>> userMeta = {};

        for (final doc in docs) {
          final d = doc.data();
          final uid = (d['authorUid'] ?? '').toString();
          if (uid.isEmpty) continue;

          userMeta[uid] = {
            'username': d['authorUsername'] ?? 'Unknown',
            'avatarUrl': d['authorAvatarUrl'] ?? '',
          };

          storiesByUser.putIfAbsent(uid, () => []);
          storiesByUser[uid]!.add(
            _StoryData(
              id: doc.id,
              mediaUrl: d['mediaUrl'],
              mediaType: d['mediaType'],
              createdAt: (d['createdAt'] as Timestamp).toDate(),
            ),
          );
        }

        final myStories = storiesByUser[myUid] ?? [];
        final others = storiesByUser.entries
            .where((e) => e.key != myUid)
            .toList();

        return FutureBuilder<List<MapEntry<String, List<_StoryData>>>>(
          future: _sortStoriesByViewed(others),
          builder: (context, sortedSnap) {
            if (!sortedSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final sortedOthers = sortedSnap.data!;

            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 1 + sortedOthers.length,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _StoryCircle(
                    username: 'Your Story',
                    avatarUrl: '',
                    hasPlus: true,
                    onTapAvatar: () {
                      if (myStories.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _StoryViewerScreen(
                              userId: myUid,
                              username: 'You',
                              avatarUrl: '',
                              stories: myStories,
                              isOwner: true,
                            ),
                          ),
                        );
                      } else {
                        _openCreateStorySheet(context);
                      }
                    },
                    onTapPlus: () => _openCreateStorySheet(context),
                  );
                }

                final e = sortedOthers[i - 1];
                final meta = userMeta[e.key]!;

                return StreamBuilder<bool>(
                  stream: _isStoryViewedStream(e.key),
                  builder: (context, snap) {
                    final isViewed = snap.data ?? false;

                    return _StoryCircle(
                      username: meta['username'],
                      avatarUrl: meta['avatarUrl'],
                      hasPlus: false,
                      isViewed: isViewed,
                      onTapAvatar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _StoryViewerScreen(
                              userId: e.key,
                              username: meta['username'],
                              avatarUrl: meta['avatarUrl'],
                              stories: e.value,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
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
}

// ---------- SIMPLE STORY DATA MODEL ----------
class _StoryData {
  final String id;
  final String mediaUrl;
  final String mediaType; // 'image'
  final DateTime createdAt;

  _StoryData({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
  });
}

// ---------- STORY CIRCLE ----------
class _StoryCircle extends StatelessWidget {
  final String username;
  final String avatarUrl;
  final bool hasPlus;
  final bool isViewed;
  final VoidCallback? onTapAvatar;
  final VoidCallback? onTapPlus;

  const _StoryCircle({
    required this.username,
    required this.avatarUrl,
    required this.hasPlus,
    this.isViewed = false,
    this.onTapAvatar,
    this.onTapPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: onTapAvatar,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: isViewed
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(color: Colors.grey, width: 2),
                        )
                      : const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.pinkAccent, Colors.orangeAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.black,
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              ),
              if (hasPlus)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onTapPlus ?? onTapAvatar,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 70,
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- MEDIA WIDGET FOR POSTS (images only) ----------
class _KritMedia extends StatelessWidget {
  final String mediaUrl;
  final String mediaType; // 'image' or 'none'

  const _KritMedia({required this.mediaUrl, required this.mediaType});

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'image') {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            );
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ---------- STORY VIEWER ----------
class _StoryViewerScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String? avatarUrl;
  final List<_StoryData> stories;
  final int initialIndex;
  final bool isOwner;

  const _StoryViewerScreen({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.stories,
    this.initialIndex = 0,
    this.isOwner = false,
  });

  @override
  State<_StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<_StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late List<_StoryData> _stories;
  late int _currentIndex;

  late AnimationController _progressController;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();

    // Create a local copy of stories
    _stories = List<_StoryData>.from(widget.stories);

    // If there are no stories, close the viewer after the first frame.
    if (_stories.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    // Keep index inside bounds
    _currentIndex = widget.initialIndex.clamp(0, _stories.length - 1).toInt();

    _progressController = AnimationController(vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });

    _loadCurrentStory();
    // 🔹 Mark stories as viewed (after first frame)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final viewerUid = currentUser.uid;
      final authorUid = widget.userId;

      await FirebaseFirestore.instance
          .collection('storyViews')
          .doc('${viewerUid}_$authorUid')
          .set({
            'viewerUid': viewerUid,
            'authorUid': authorUid,
            'viewedAt': Timestamp.now(), // instant (for UI)
            'serverViewedAt': FieldValue.serverTimestamp(), // optional
          }, SetOptions(merge: true));
    });
  }

  // Defensive getter — ensures index is valid
  _StoryData get _currentStory {
    if (_stories.isEmpty) {
      throw StateError("No stories available");
    }

    if (_currentIndex >= _stories.length) {
      _currentIndex = _stories.length - 1;
    }
    if (_currentIndex < 0) {
      _currentIndex = 0;
    }

    return _stories[_currentIndex];
  }

  Future<void> _loadCurrentStory() async {
    // If list emptied while viewer open, close viewer gracefully
    if (_stories.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Ensure we have a controller (initState may have returned early)
    if (!mounted) return;

    _progressController.stop();
    _progressController.reset();

    // Safe to read current story now
    if (!mounted || _stories.isEmpty) return;

    final story = _currentStory;
    _progressController.duration = const Duration(seconds: 5);

    if (mounted) _progressController.forward(from: 0);

    if (mounted) setState(() {});
  }

  void _nextStory() {
    if (_stories.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (_currentIndex < _stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadCurrentStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    if (_stories.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadCurrentStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _pauseStory() {
    if (_isPaused) return;
    _isPaused = true;
    _progressController.stop();
    if (mounted) setState(() {});
  }

  void _resumeStory() {
    if (!_isPaused) return;
    _isPaused = false;
    if (_progressController.value < 1.0) {
      _progressController.forward();
    }
    if (mounted) setState(() {});
  }

  Future<void> _deleteCurrentStory() async {
    if (_stories.isEmpty) return;

    final story = _currentStory;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete story?'),
        content: const Text('This story will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;

      // 1️⃣ Load Firestore document to get storagePath
      final doc = await FirebaseFirestore.instance
          .collection('stories')
          .doc(story.id)
          .get();

      final data = doc.data();
      final storagePath = data?['storagePath'];

      // 2️⃣ Delete Supabase file (if exists)
      if (storagePath != null &&
          storagePath is String &&
          storagePath.isNotEmpty) {
        await supabase.storage.from('stories_media').remove([storagePath]);
      }

      // 3️⃣ Delete Firestore document
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(story.id)
          .delete();

      if (!mounted) return;

      // 4️⃣ Remove locally
      setState(() {
        _stories.removeAt(_currentIndex);

        if (_stories.isEmpty) {
          Future.microtask(() {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return;
        }

        if (_currentIndex >= _stories.length) {
          _currentIndex = _stories.length - 1;
        }
      });

      if (mounted && _stories.isNotEmpty) await _loadCurrentStory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete story')));
    }
  }

  double _progressValueForIndex(int i) {
    if (_stories.isEmpty) return 0.0;
    if (i < _currentIndex) return 1.0;
    if (i == _currentIndex) return _progressController.value.clamp(0.0, 1.0);
    return 0.0;
  }

  @override
  void dispose() {
    // Only dispose if controller was created
    try {
      _progressController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If stories emptied, close quickly and avoid indexing
    if (_stories.isEmpty) {
      Future.microtask(() {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final story = _currentStory;
    final content = Center(
      child: Image.network(story.mediaUrl, fit: BoxFit.contain),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (_) => Navigator.pop(context),
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          final dx = details.localPosition.dx;
          if (dx < width / 3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: content),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(_stories.length, (index) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: _progressValueForIndex(index),
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PlayerProfileScreen(userId: widget.userId),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white24,
                                backgroundImage:
                                    (widget.avatarUrl != null &&
                                        widget.avatarUrl!.isNotEmpty)
                                    ? NetworkImage(widget.avatarUrl!)
                                    : null,
                                child:
                                    (widget.avatarUrl == null ||
                                        widget.avatarUrl!.isEmpty)
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (widget.isOwner)
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteCurrentStory();
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete story',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- CREATE KRIT (POST) SHEET (image-only, cropping + compress + upload) ----------
class _CreateKritSheet extends StatefulWidget {
  const _CreateKritSheet();

  @override
  State<_CreateKritSheet> createState() => _CreateKritSheetState();
}

class _CreateKritSheetState extends State<_CreateKritSheet> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _gameController = TextEditingController();

  XFile? _pickedMedia;
  String? _pickedMediaType;

  bool _isPosting = false;
  String? _errorText;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _textController.dispose();
    _gameController.dispose();
    super.dispose();
  }

  // ---- Image pick + crop + compress helper ----
  Future<Uint8List?> _pickCropAndCompressImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust image',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),

        IOSUiSettings(title: 'Adjust image'),
      ],
    );

    if (cropped == null) return null;

    final originalBytes = await File(cropped.path).readAsBytes();

    return originalBytes; // no compression
  }

  // ---- Upload helper: returns map {mediaUrl, storagePath} ----
  Future<Map<String, String>?> _uploadImageBytesToSupabase(
    Uint8List bytes,
    String uid, {
    String bucket = 'stories_media',
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${uid}_$timestamp.jpg';
      final storagePath = '$uid/$fileName';
      final supabase = Supabase.instance.client;

      await supabase.storage.from(bucket).uploadBinary(storagePath, bytes);

      final dynamic public = supabase.storage
          .from(bucket)
          .getPublicUrl(storagePath);

      String url;
      if (public == null) {
        url = '';
      } else if (public is String) {
        url = public;
      } else if (public is Map) {
        if (public.containsKey('publicUrl') &&
            (public['publicUrl'] is String)) {
          url = public['publicUrl'] as String;
        } else if (public.containsKey('data') && (public['data'] is String)) {
          url = public['data'] as String;
        } else {
          url = public.toString();
        }
      } else {
        url = public.toString();
      }

      if (url.isEmpty) return null;
      return {'mediaUrl': url, 'storagePath': storagePath};
    } catch (e, st) {
      debugPrint('Supabase upload error: $e\n$st');
      return null;
    }
  }

  Future<void> _onPickPhotoPressed() async {
    setState(() {
      _errorText = null;
    });

    final bytes = await _pickCropAndCompressImage();
    if (bytes == null) return;

    // save bytes to temp file so preview shows the compressed image exactly
    final tempDir = await getTemporaryDirectory();
    final filePath = p.join(
      tempDir.path,
      'krit_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    setState(() {
      _pickedMedia = XFile(filePath);
      _pickedMediaType = 'image';
    });
  }

  Future<void> _postKrit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorText = 'You must be logged in to post.';
      });
      return;
    }

    setState(() {
      _isPosting = true;
      _errorText = null;
    });

    try {
      String mediaUrl = '';
      String mediaType = 'none';
      String? storagePath;

      if (_pickedMedia != null && _pickedMediaType == 'image') {
        final bytes = await File(_pickedMedia!.path).readAsBytes();
        final upload = await _uploadImageBytesToSupabase(
          bytes,
          currentUser.uid,
          bucket: 'krit_media',
        );
        if (upload == null) {
          setState(() {
            _errorText = 'Failed to upload image.';
            _isPosting = false;
          });
          return;
        }
        mediaUrl = upload['mediaUrl']!;
        storagePath = upload['storagePath'];
        mediaType = 'image';
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? 'Unknown';
      final avatarUrl = (userData['avatarUrl'] ?? '').toString();

      final ref = FirebaseFirestore.instance.collection('krits').doc();

      await ref.set({
        'id': ref.id,
        'authorUid': currentUser.uid,
        'authorUsername': username,
        'authorAvatarUrl': avatarUrl,
        'text': _textController.text.trim(),
        'game': _gameController.text.trim(),
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'storagePath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('postKrit error: $e');
      setState(() {
        _errorText = 'Failed to post. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget mediaPreview = const SizedBox.shrink();
    if (_pickedMedia != null && _pickedMediaType == 'image') {
      mediaPreview = Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Image.file(
          File(_pickedMedia!.path),
          height: 180,
          fit: BoxFit.cover,
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Krit',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _textController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Text required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _gameController,
                decoration: const InputDecoration(
                  hintText: 'Game tag (optional, e.g. Valorant)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _onPickPhotoPressed,
                    icon: const Icon(Icons.photo),
                    label: const Text('Photo'),
                  ),
                ],
              ),
              mediaPreview,
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isPosting ? null : _postKrit,
                child: _isPosting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- CREATE STORY SHEET ----------
class _CreateStorySheet extends StatefulWidget {
  const _CreateStorySheet();

  @override
  State<_CreateStorySheet> createState() => _CreateStorySheetState();
}

class _CreateStorySheetState extends State<_CreateStorySheet> {
  XFile? _pickedMedia;
  String? _pickedMediaType;

  bool _isPosting = false;
  String? _errorText;

  final _picker = ImagePicker();

  Future<Uint8List?> _pickCropAndCompressImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust image',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          initAspectRatio:
              CropAspectRatioPreset.original, // single correct argument
          lockAspectRatio: false,
        ),

        IOSUiSettings(title: 'Adjust image'),
      ],
    );

    if (cropped == null) return null;

    final originalBytes = await File(cropped.path).readAsBytes();

    return originalBytes;
  }

  Future<Map<String, String>?> _uploadImageBytesToSupabase(
    Uint8List bytes,
    String uid, {
    String bucket = 'stories_media',
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${uid}_$timestamp.jpg';
      final storagePath = '$uid/$fileName';
      final supabase = Supabase.instance.client;

      await supabase.storage.from(bucket).uploadBinary(storagePath, bytes);

      final dynamic public = supabase.storage
          .from(bucket)
          .getPublicUrl(storagePath);

      String url;
      if (public == null) {
        url = '';
      } else if (public is String) {
        url = public;
      } else if (public is Map) {
        if (public.containsKey('publicUrl') &&
            (public['publicUrl'] is String)) {
          url = public['publicUrl'] as String;
        } else if (public.containsKey('data') && (public['data'] is String)) {
          url = public['data'] as String;
        } else {
          url = public.toString();
        }
      } else {
        url = public.toString();
      }

      if (url.isEmpty) return null;
      return {'mediaUrl': url, 'storagePath': storagePath};
    } catch (e, st) {
      debugPrint('Supabase upload error: $e\n$st');
      return null;
    }
  }

  Future<void> _onPickPhotoPressed() async {
    setState(() {
      _errorText = null;
    });

    final bytes = await _pickCropAndCompressImage();
    if (bytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final filePath = p.join(
      tempDir.path,
      'story_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    setState(() {
      _pickedMedia = XFile(filePath);
      _pickedMediaType = 'image';
    });
  }

  Future<void> _postStory() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorText = 'You must be logged in to post a story.';
      });
      return;
    }

    if (_pickedMedia == null || _pickedMediaType != 'image') {
      setState(() {
        _errorText = 'Pick an image.';
      });
      return;
    }

    setState(() {
      _isPosting = true;
      _errorText = null;
    });

    try {
      final bytes = await File(_pickedMedia!.path).readAsBytes();
      final upload = await _uploadImageBytesToSupabase(
        bytes,
        currentUser.uid,
        bucket: 'stories_media',
      );
      if (upload == null) {
        setState(() {
          _errorText = 'Failed to upload media.';
          _isPosting = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? 'Unknown';
      final avatarUrl = (userData['avatarUrl'] ?? '').toString();

      final ref = FirebaseFirestore.instance.collection('stories').doc();
      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      );

      await ref.set({
        'id': ref.id,
        'authorUid': currentUser.uid,
        'authorUsername': username,
        'authorAvatarUrl': avatarUrl,
        'mediaUrl': upload['mediaUrl'],
        'storagePath':
            upload['storagePath'], // IMPORTANT: required for deletion
        'mediaType': 'image',
        'createdAt': now,
        'expiresAt': expiresAt,
      });
      // 🔹 Register story for Supabase cleanup (TTL replacement)
      final supabase = Supabase.instance.client;

      await supabase.from('story_cleanup').insert({
        'firestore_id': ref.id,
        'storage_path': upload['storagePath'],
        'expires_at': expiresAt.toDate().toUtc().toIso8601String(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('postStory error: $e');
      setState(() {
        _errorText = 'Failed to post story. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget preview = const SizedBox.shrink();
    if (_pickedMedia != null && _pickedMediaType == 'image') {
      preview = Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Image.file(
          File(_pickedMedia!.path),
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Story',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_errorText != null) ...[
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                TextButton.icon(
                  onPressed: _onPickPhotoPressed,
                  icon: const Icon(Icons.photo),
                  label: const Text('Photo'),
                ),
              ],
            ),
            preview,
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isPosting ? null : _postStory,
              child: _isPosting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Share Story'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- LIKE BUTTON (no change) ----------

// ---------- NOTIFICATIONS SCREEN (unchanged) ----------
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _connectionsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('connections')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _acceptRequest(String myUid, String otherUid) async {
    final batch = FirebaseFirestore.instance.batch();

    final myRef = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('connections')
        .doc(otherUid);

    final otherRef = FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .collection('connections')
        .doc(myUid);

    batch.update(myRef, {
      'status': 'connected',
      'connectedAt': FieldValue.serverTimestamp(),
    });

    batch.update(otherRef, {
      'status': 'connected',
      'connectedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> _ignoreRequest(String myUid, String otherUid) async {
    final batch = FirebaseFirestore.instance.batch();

    final myRef = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('connections')
        .doc(otherUid);

    final otherRef = FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .collection('connections')
        .doc(myUid);

    batch.delete(myRef);
    batch.delete(otherRef);

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Log in to see notifications')),
      );
    }

    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // filler notifications
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.grey[900],
                  child: ListTile(
                    leading: const Icon(Icons.edit_calendar_outlined),
                    title: const Text('Post something today'),
                    subtitle: const Text('Share a new krit with your friends.'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Go to Feed and tap + to post'),
                        ),
                      );
                    },
                  ),
                ),
                Card(
                  color: Colors.grey[900],
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Complete your profile'),
                    subtitle: const Text(
                      'Add more game profiles to get better matches.',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _connectionsStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading notifications'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No connection notifications yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final connDoc = docs[index];
                    final data = connDoc.data();
                    final otherUid = (data['uid'] ?? '').toString();
                    final status = (data['status'] ?? '').toString();

                    if (otherUid.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return FutureBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUid)
                          .get(),
                      builder: (context, userSnap) {
                        String username = 'Player';
                        String avatarUrl = '';

                        if (userSnap.hasData && userSnap.data!.exists) {
                          final uData = userSnap.data!.data()!;
                          username = (uData['username'] ?? 'Player').toString();
                          avatarUrl = (uData['avatarUrl'] ?? '').toString();
                        }

                        String subtitle;
                        Widget? trailing;

                        if (status == 'requested') {
                          subtitle = '$username wants to connect with you';
                          trailing = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _ignoreRequest(uid, otherUid),
                                child: const Text(
                                  'Ignore',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                onPressed: () => _acceptRequest(uid, otherUid),
                                child: const Text('Accept'),
                              ),
                            ],
                          );
                        } else if (status == 'pending') {
                          subtitle = 'Connection request sent to $username';
                        } else if (status == 'connected') {
                          subtitle = 'You are now connected with $username';
                        } else {
                          subtitle = 'Status: $status';
                        }

                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[800],
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(username),
                            subtitle: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: trailing,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KritCommentButton extends StatelessWidget {
  final String kritId;
  final int initialCount;

  const _KritCommentButton({required this.kritId, required this.initialCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.mode_comment_outlined, color: Colors.white),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.black,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => _CommentsSheet(kritId: kritId),
            );
          },
        ),
        Text(
          '$initialCount',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String kritId;
  const _CommentsSheet({required this.kritId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _replyToCommentId;
  String? _replyToUsername;
  bool _sending = false;

  void _setReply(String parentId, String username) {
    setState(() {
      _replyToCommentId = parentId;
      _replyToUsername = username;
    });
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
    });
  }

  Future<void> _sendComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _controller.text.trim().isEmpty) return;

    setState(() => _sending = true);

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final u = userDoc.data() ?? {};

    final kritRef = FirebaseFirestore.instance
        .collection('krits')
        .doc(widget.kritId);
    final commentRef = kritRef.collection('comments').doc();

    final batch = FirebaseFirestore.instance.batch();

    batch.set(commentRef, {
      'id': commentRef.id,
      'uid': user.uid,
      'username': u['username'] ?? 'Player',
      'avatarUrl': u['avatarUrl'] ?? '',
      'text': _controller.text.trim(),
      'parentId': _replyToCommentId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (_replyToCommentId == null) {
      batch.update(kritRef, {'commentCount': FieldValue.increment(1)});
    }

    await batch.commit();

    _controller.clear();
    _clearReply();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            /// HANDLE + TITLE
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: const [
                  SizedBox(
                    width: 40,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Comments',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            /// COMMENTS LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('krits')
                    .doc(widget.kritId)
                    .collection('comments')
                    .orderBy('createdAt')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  final top = docs
                      .where((d) => d.data()['parentId'] == null)
                      .toList();

                  final replies = <String, List<QueryDocumentSnapshot>>{};
                  for (final d in docs) {
                    final pid = d.data()['parentId'];
                    if (pid != null) {
                      replies.putIfAbsent(pid, () => []).add(d);
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: top.length,
                    itemBuilder: (context, i) {
                      final c = top[i];
                      return _CommentTile(
                        data: c.data(),
                        replies: replies[c.id] ?? [],
                        onReply: () => _setReply(c.id, c.data()['username']),
                      );
                    },
                  );
                },
              ),
            ),

            /// REPLY INFO BAR
            if (_replyToUsername != null)
              Container(
                color: Colors.grey[900],
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Text(
                      'Replying to $_replyToUsername',
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearReply,
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),

            /// INSTAGRAM STYLE INPUT
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment…',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _sendComment,
                      child: Text(
                        'Post',
                        style: TextStyle(
                          color: _controller.text.trim().isEmpty
                              ? Colors.grey
                              : Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReply;
  final List<QueryDocumentSnapshot> replies;

  const _CommentTile({
    required this.data,
    required this.replies,
    required this.onReply,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _showReplies = false;

  @override
  Widget build(BuildContext context) {
    final replyCount = widget.replies.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// MAIN COMMENT
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlayerProfileScreen(userId: widget.data['uid']),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: (widget.data['avatarUrl'] ?? '').isNotEmpty
                      ? NetworkImage(widget.data['avatarUrl'])
                      : null,
                  child: (widget.data['avatarUrl'] ?? '').isEmpty
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: widget.data['username'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: widget.data['text'],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: widget.onReply,
                      child: const Text(
                        'Reply',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          /// VIEW / HIDE REPLIES
          if (replyCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showReplies = !_showReplies;
                  });
                },
                child: Text(
                  _showReplies ? 'Hide replies' : 'View replies ($replyCount)',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          /// REPLIES LIST
          if (_showReplies)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 6),
              child: Column(
                children: widget.replies.map((r) {
                  final d = r.data() as Map<String, dynamic>;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: (d['avatarUrl'] ?? '').isNotEmpty
                              ? NetworkImage(d['avatarUrl'])
                              : null,
                          child: (d['avatarUrl'] ?? '').isEmpty
                              ? const Icon(Icons.person, size: 12)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: d['username'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const TextSpan(text: '  '),
                                    TextSpan(
                                      text: d['text'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: widget.onReply,
                                child: const Text(
                                  'Reply',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _LikeableMedia extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final VoidCallback onLike;
  final bool isLiked;

  const _LikeableMedia({
    required this.mediaUrl,
    required this.mediaType,
    required this.onLike,
    required this.isLiked,
  });

  @override
  State<_LikeableMedia> createState() => _LikeableMediaState();
}

class _LikeableMediaState extends State<_LikeableMedia>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  void _onDoubleTap() {
    if (!widget.isLiked) {
      widget.onLike();
    }
    setState(() => _showHeart = true);
    _controller.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showHeart = false);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _KritMedia(mediaUrl: widget.mediaUrl, mediaType: widget.mediaType),

          if (_showHeart)
            ScaleTransition(
              scale: _scale,
              child: const Icon(Icons.favorite, color: Colors.white, size: 100),
            ),
        ],
      ),
    );
  }
}

class _KritLikeController extends StatefulWidget {
  final String kritId;
  final int initialCount;
  final String mediaUrl;
  final String mediaType;
  final int commentCount;

  const _KritLikeController({
    required this.kritId,
    required this.initialCount,
    required this.commentCount,
    required this.mediaUrl,
    required this.mediaType,
  });

  @override
  State<_KritLikeController> createState() => _KritLikeControllerState();
}

class _KritLikeControllerState extends State<_KritLikeController> {
  late bool _isLiked;
  late int _likeCount;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.initialCount;
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLiked = false;
      _loading = false;
      setState(() {});
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('krits')
        .doc(widget.kritId)
        .collection('likes')
        .doc(user.uid)
        .get();

    _isLiked = doc.exists;
    _loading = false;
    if (mounted) setState(() {});
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('krits')
        .doc(widget.kritId);
    final likeRef = ref.collection('likes').doc(user.uid);

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    if (_isLiked) {
      await likeRef.set({'createdAt': FieldValue.serverTimestamp()});
      await ref.update({'likeCount': FieldValue.increment(1)});
    } else {
      await likeRef.delete();
      await ref.update({'likeCount': FieldValue.increment(-1)});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 200);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// MEDIA
        _LikeableMedia(
          mediaUrl: widget.mediaUrl,
          mediaType: widget.mediaType,
          isLiked: _isLiked,
          onLike: _toggleLike,
        ),

        /// ACTION ROW
        _PostActionRow(
          isLiked: _isLiked,
          likeCount: _likeCount,
          commentCount: widget.commentCount,
          onLike: _toggleLike,
          onComment: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.black,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => _CommentsSheet(kritId: widget.kritId),
            );
          },
        ),

        /// LIKE COUNT
      ],
    );
  }
}

class _AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;

  const _AnimatedLikeButton({required this.isLiked, required this.onTap});

  @override
  State<_AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<_AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLiked && widget.isLiked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: IconButton(
        icon: Icon(
          widget.isLiked ? Icons.favorite : Icons.favorite_border,
          color: widget.isLiked ? Colors.redAccent : Colors.white,
        ),
        onPressed: widget.onTap,
      ),
    );
  }
}

class _PostActionRow extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _PostActionRow({
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          /// LIKE
          GestureDetector(
            onTap: onLike,
            child: Row(
              children: [
                Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.redAccent : Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 4),
                Text(
                  likeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 18),

          /// COMMENT
          GestureDetector(
            onTap: onComment,
            child: Row(
              children: [
                const Icon(
                  Icons.mode_comment_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 4),
                Text(
                  commentCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
