import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kritun/features/messages/presentation/direct_chat_screen.dart';

class DMListScreen extends StatelessWidget {
  const DMListScreen({super.key});

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  // All chats where current user participates
  Stream<QuerySnapshot<Map<String, dynamic>>> _chatsStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _currentUid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Messages',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error loading chats',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "No messages yet",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Start a chat from a player profile.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final chatDoc = docs[index];
              final data = chatDoc.data();
              final chatId = chatDoc.id;

              final participants = List<String>.from(
                data['participants'] ?? [],
              );
              String otherUid = _currentUid;
              if (participants.length >= 2) {
                otherUid = participants.firstWhere(
                  (id) => id != _currentUid,
                  orElse: () => _currentUid,
                );
              }

              final updatedAtTs = data['updatedAt'];
              DateTime? updatedAt;
              if (updatedAtTs is Timestamp) {
                updatedAt = updatedAtTs.toDate();
              }

              return _ChatListTile(
                chatId: chatId,
                otherUserId: otherUid,
                currentUid: _currentUid,
                updatedAt: updatedAt,
              );
            },
          );
        },
      ),
    );
  }
}

Widget _unreadBadge(int count) {
  if (count <= 0) return const SizedBox.shrink();

  if (count == 1) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.blue,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      count > 9 ? '9+' : count.toString(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _ChatListTile extends StatelessWidget {
  final String chatId;
  final String otherUserId;
  final String currentUid;
  final DateTime? updatedAt;

  const _ChatListTile({
    required this.chatId,
    required this.otherUserId,
    required this.currentUid,
    this.updatedAt,
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadOtherUser() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(otherUserId)
        .get();
  }

  // last message stream for subtitle
  Stream<QuerySnapshot<Map<String, dynamic>>> _lastMessageStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dateTime.day}/${dateTime.month}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _loadOtherUser(),
      builder: (context, userSnap) {
        String username = 'Unknown';
        String avatarUrl = '';

        if (userSnap.hasData && userSnap.data!.exists) {
          final data = userSnap.data!.data()!;
          username = (data['username'] ?? 'Unknown').toString();
          avatarUrl = (data['avatarUrl'] ?? '').toString();
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _lastMessageStream(),
          builder: (context, msgSnap) {
            String subtitle = '';
            if (msgSnap.hasData && msgSnap.data!.docs.isNotEmpty) {
              final msg = msgSnap.data!.docs.first.data();
              subtitle = (msg['text'] ?? '').toString();
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .snapshots(),
              builder: (context, chatSnap) {
                final unreadMap = Map<String, dynamic>.from(
                  chatSnap.data?.data()?['unreadCount'] ?? {},
                );

                final int unreadCount = unreadMap[currentUid] ?? 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: subtitle.isNotEmpty
                          ? Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            )
                          : const Text(
                              'Tap to start chatting',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (updatedAt != null)
                            Text(
                              _timeAgo(updatedAt!),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(height: 6),
                          _unreadBadge(unreadCount),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DirectChatScreen(
                              chatId: chatId,
                              otherUserId: otherUserId,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
