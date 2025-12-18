import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kritun/features/trials/my_trials_screen.dart';
import 'package:kritun/features/home/presentation/krit_detail_screen.dart';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kritun/features/profile/presentation/connections_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _isUpdatingAvatar = false;

  void _openAddGameProfileSheet(BuildContext context) {
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
          child: _AddGameProfileForm(),
        );
      },
    );
  }

  // user doc stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  // Krits (posts) created by this user
  Stream<QuerySnapshot<Map<String, dynamic>>> _myKritsStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('krits')
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Game profiles for this user
  Stream<QuerySnapshot<Map<String, dynamic>>> _gameProfilesStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gameProfiles')
        .snapshots();
  }

  // Teams with this user as member
  Stream<QuerySnapshot<Map<String, dynamic>>> _myTeamsStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('teams')
        .where('memberUids', arrayContains: uid)
        .snapshots();
  }

  // Small stat item like Insta (Posts / Connections / Teams)
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

  // 🔥 Change avatar: pick → crop → upload → save avatarUrl → update posts & stories
  Future<void> _changeAvatar() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust',
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: 'Adjust', aspectRatioLockEnabled: true),
        ],
      );

      if (cropped == null) return;

      setState(() => _isUpdatingAvatar = true);

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final file = File(cropped.path);
      final ext = cropped.path.split('.').last;

      // unique name
      final millis = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'avatar_${uid}_$millis.$ext';
      const bucketName = 'krit_media';
      final storagePath = 'avatars/$uid/$fileName';

      final supabase = Supabase.instance.client;
      final bytes = await file.readAsBytes();

      await supabase.storage
          .from(bucketName)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage
          .from(bucketName)
          .getPublicUrl(storagePath);

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'avatarUrl': publicUrl,
        'avatarUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update old posts & stories avatar
      final batch = FirebaseFirestore.instance.batch();

      final kritsSnap = await FirebaseFirestore.instance
          .collection('krits')
          .where('authorUid', isEqualTo: uid)
          .get();
      for (final d in kritsSnap.docs) {
        batch.update(d.reference, {'authorAvatarUrl': publicUrl});
      }

      final storiesSnap = await FirebaseFirestore.instance
          .collection('stories')
          .where('authorUid', isEqualTo: uid)
          .get();
      for (final d in storiesSnap.docs) {
        batch.update(d.reference, {'authorAvatarUrl': publicUrl});
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated')));
    } catch (e, st) {
      debugPrint('Avatar update error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update picture')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "Profile",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading profile"));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Profile not found"));
          }

          final data = snapshot.data!.data()!;
          final username = (data['username'] ?? 'Unknown').toString();
          final email = (data['email'] ?? '').toString();
          final createdAt = data['createdAt']?.toDate();
          final avatarUrl = (data['avatarUrl'] ?? '').toString();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ========== HEADER (avatar + stats row) ==========
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          GestureDetector(
                            onTap: _isUpdatingAvatar ? null : _changeAvatar,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(Icons.person, size: 36)
                                  : null,
                            ),
                          ),
                          if (_isUpdatingAvatar)
                            const Positioned.fill(
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              margin: const EdgeInsets.only(
                                bottom: 2,
                                right: 2,
                              ),
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // stats row like Insta
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _myKritsStream(),
                              builder: (context, snap) {
                                final count = snap.data?.docs.length ?? 0;
                                return _statItem(label: 'Posts', value: count);
                              },
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ConnectionsListScreen(uid: uid),
                                  ),
                                );
                              },
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('connections')
                                    .snapshots(),
                                builder: (context, snap) {
                                  final count = snap.data?.docs.length ?? 0;
                                  return _statItem(
                                    label: 'Connections',
                                    value: count,
                                  );
                                },
                              ),
                            ),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _myTeamsStream(),
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

                  // username + small info
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

                  // buttons row like insta (edit / trials)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openAddGameProfileSheet(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Add game profile',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MyTrialsScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'View trials',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 16),

                  // ========== Performance (Trials) ==========
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "Performance",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "(Trials)",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('trials')
                        .where(
                          'targetUid',
                          isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                        )
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
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
                          "No trials played yet. Join trials to build your rating.",
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
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

                  const SizedBox(height: 18),

                  // ========== Game Profiles (horizontal like highlights) ==========
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Game Profiles",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openAddGameProfileSheet(context),
                        child: const Text(
                          "Add",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _gameProfilesStream(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      if (snap.hasError) {
                        return const Text(
                          "Error loading game profiles. Please try again.",
                          style: TextStyle(color: Colors.redAccent),
                        );
                      }

                      final docs = snap.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Text(
                          "No game profiles yet. Add one to start getting better matches.",
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      return SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final g = doc.data();

                            final gameName = (g['gameName'] ?? 'Unknown game')
                                .toString();
                            final inGameId = (g['inGameId'] ?? '').toString();
                            final region = (g['region'] ?? '').toString();
                            final role = (g['primaryRole'] ?? '').toString();
                            final current = (g['currentRank'] ?? '').toString();
                            final peak = (g['peakRank'] ?? '').toString();

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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (inGameId.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                "In-game ID: $inGameId",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          if (region.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                "Region: $region",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          if (role.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                "Primary role: $role",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          if (current.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                "Current rank: $current",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          if (peak.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                "Peak rank: $peak",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
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
                                  border: Border.all(
                                    color: Colors.white12,
                                    width: 0.5,
                                  ),
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
                                    if (current.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          "Rank: $current",
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
                                    const Spacer(),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: GestureDetector(
                                        onTap: () async {
                                          await doc.reference.delete();
                                        },
                                        child: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.white54,
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

                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 12),

                  // ========== Posts grid ==========
                  const Text(
                    "Posts",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _myKritsStream(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
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
                          "You haven't posted any krits yet.",
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                          final mediaType = (data['mediaType'] ?? 'none')
                              .toString();
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
                          } else if (mediaType == 'video' &&
                              mediaUrl.isNotEmpty) {
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
                                  builder: (_) =>
                                      KritDetailScreen(kritId: doc.id),
                                ),
                              );
                            },
                            child: child,
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 12),

                  // ========== My Teams ==========
                  const Text(
                    "My Teams",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _myTeamsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                          "You haven't created any teams yet.",
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                "Game: $game · Region: $region",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddGameProfileForm extends StatefulWidget {
  @override
  State<_AddGameProfileForm> createState() => _AddGameProfileFormState();
}

class _AddGameProfileFormState extends State<_AddGameProfileForm> {
  final _formKey = GlobalKey<FormState>();

  final _gameNameController = TextEditingController();
  final _inGameIdController = TextEditingController();
  final _regionController = TextEditingController();
  final _roleController = TextEditingController();
  final _currentRankController = TextEditingController();
  final _peakRankController = TextEditingController();

  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _gameNameController.dispose();
    _inGameIdController.dispose();
    _regionController.dispose();
    _roleController.dispose();
    _currentRankController.dispose();
    _peakRankController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('gameProfiles')
          .doc();

      await ref.set({
        'id': ref.id,
        'gameName': _gameNameController.text.trim(),
        'inGameId': _inGameIdController.text.trim(),
        'region': _regionController.text.trim(),
        'primaryRole': _roleController.text.trim(),
        'currentRank': _currentRankController.text.trim(),
        'peakRank': _peakRankController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorText = "Failed to save. Please try again.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                "Add Game Profile",
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
                controller: _gameNameController,
                decoration: const InputDecoration(
                  hintText: "Game (e.g. Valorant)",
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Game name required"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _inGameIdController,
                decoration: const InputDecoration(
                  hintText: "In-game ID / username",
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _regionController,
                decoration: const InputDecoration(hintText: "Region / Server"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(
                  hintText: "Primary role (e.g. Duelist)",
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _currentRankController,
                decoration: const InputDecoration(
                  hintText: "Current rank/tier",
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _peakRankController,
                decoration: const InputDecoration(hintText: "Peak rank"),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save"),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoGridThumb extends StatelessWidget {
  final String url;

  const _VideoGridThumb({required this.url});

  Future<Uint8List?> _generateThumb() {
    return VideoThumbnail.thumbnailData(
      video: url,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 400, // grid tile size-ish
      quality: 75,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _generateThumb(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Loading state
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
          // Fallback if thumbnail fails
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
