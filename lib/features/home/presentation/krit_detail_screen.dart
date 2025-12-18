import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KritDetailScreen extends StatelessWidget {
  final String kritId;

  const KritDetailScreen({super.key, required this.kritId});

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadKrit() {
    return FirebaseFirestore.instance.collection('krits').doc(kritId).get();
  }

  Future<void> _deleteKrit(BuildContext context) async {
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will permanently delete this post.'),
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
      final docRef = FirebaseFirestore.instance.collection('krits').doc(kritId);

      final doc = await docRef.get();
      final data = doc.data();

      final String? storagePath = data?['storagePath'];

      // 🔥 DELETE FROM SUPABASE USING STORAGE PATH
      if (storagePath != null && storagePath.isNotEmpty) {
        await Supabase.instance.client.storage.from('krit_media').remove([
          storagePath,
        ]);
      }

      // 🔥 DELETE FIRESTORE DOC
      await docRef.delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post deleted')));

      navigator.pop();
    } catch (e) {
      debugPrint('Delete error: $e');

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete post')));
    }
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _loadKrit(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading post.'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Post not found.'));
          }

          final data = snapshot.data!.data()!;
          final currentUid = FirebaseAuth.instance.currentUser?.uid;

          final authorUid = (data['authorUid'] ?? '').toString();
          final authorUsername = (data['authorUsername'] ?? 'Unknown')
              .toString();
          final text = (data['text'] ?? '').toString();
          final gameTag = (data['game'] ?? '').toString();
          final mediaUrl = (data['mediaUrl'] ?? '').toString();
          final mediaType = (data['mediaType'] ?? 'none').toString();
          final likeCount = (data['likeCount'] ?? 0) as int? ?? 0;

          DateTime? createdAt;
          final ts = data['createdAt'];
          if (ts is Timestamp) {
            createdAt = ts.toDate();
          }

          final isOwner = currentUid != null && currentUid == authorUid;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: avatar, username, time, delete if owner
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            child: Icon(Icons.person, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorUsername,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (createdAt != null)
                                Text(
                                  _timeAgo(createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (isOwner)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.redAccent,
                          tooltip: 'Delete post',
                          onPressed: () => _deleteKrit(context),
                        ),
                    ],
                  ),
                ),

                // Media full width
                // Media full width
                if (mediaType == 'image' && mediaUrl.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Image.network(
                      mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) {
                        return Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  )
                else if (mediaType == 'video' && mediaUrl.isNotEmpty)
                  _KritDetailVideo(mediaUrl: mediaUrl),

                // Text & game & likes
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (text.isNotEmpty) ...[
                        Text(text, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 8),
                      ],
                      if (gameTag.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.blueGrey[800],
                          ),
                          child: Text(
                            '#$gameTag',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        '$likeCount likes',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KritDetailVideo extends StatefulWidget {
  final String mediaUrl;

  const _KritDetailVideo({required this.mediaUrl});

  @override
  State<_KritDetailVideo> createState() => _KritDetailVideoState();
}

class _KritDetailVideoState extends State<_KritDetailVideo> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));

      _controller = c
        ..setLooping(true)
        ..setVolume(0.0); // muted like reels

      await c.initialize();
      if (!mounted) return;

      setState(() {
        _initialized = true;
      });

      c.play(); // autoplay
    } catch (e) {
      debugPrint('Detail video init error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return const AspectRatio(
        aspectRatio: 9 / 16,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio == 0
          ? 9 / 16
          : _controller!.value.aspectRatio,
      child: GestureDetector(
        onTap: () {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
          setState(() {});
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_controller!),
            if (!_controller!.value.isPlaying)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 64,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
