import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kritun/features/home/presentation/player_profile_screen.dart';

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const DirectChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // ---------- REPLY STATE ----------
  String? _replyToMessageId;
  String? _replyToText;
  String? _replyToSenderId;

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  @override
  void initState() {
    super.initState();

    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'activeChatUser': currentUid,
      'unreadCount.$currentUid': 0,
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final ref = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc();

    await ref.set({
      'id': ref.id,
      'senderId': currentUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      // reply meta
      'replyToMessageId': _replyToMessageId,
      'replyToText': _replyToText,
      'replyToSenderId': _replyToSenderId,
    });

    // update chat last activity + increment unread for other user
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);

    final chatSnap = await chatRef.get();
    final activeUser = chatSnap.data()?['activeChatUser'];

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (activeUser != widget.otherUserId) {
      updates['unreadCount.${widget.otherUserId}'] = FieldValue.increment(1);
    }

    await chatRef.update(updates);

    // clear reply state
    setState(() {
      _replyToMessageId = null;
      _replyToText = null;
      _replyToSenderId = null;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadOtherUser() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .get();
  }

  @override
  void dispose() {
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'activeChatUser': null,
    });

    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _loadOtherUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        String username = "Chat";
        String avatarUrl = "";

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data()!;
          username = (data['username'] ?? "Chat").toString();
          avatarUrl = (data['avatarUrl'] ?? "").toString();
        }

        // used to resolve "You" vs other name in reply labels
        final String otherUsername = username;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            titleSpacing: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PlayerProfileScreen(userId: widget.otherUserId),
                  ),
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      username,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    final messages = snapshot.data!.docs;

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          "Say hi 👋",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final doc = messages[index];
                        final msg = doc.data();
                        final isMe = msg["senderId"] == currentUid;
                        final text = (msg["text"] ?? "").toString();

                        final replyToText = (msg["replyToText"] ?? "")
                            .toString();
                        final replyToSenderId = (msg["replyToSenderId"] ?? "")
                            .toString();

                        final replyLabel = replyToSenderId.isEmpty
                            ? null
                            : (replyToSenderId == currentUid
                                  ? "You"
                                  : otherUsername);

                        final bubbleColor = isMe
                            ? const Color(0xFF3797F0)
                            : const Color(0xFF262626);
                        final alignment = isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft;

                        final radius = isMe
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
                                bottomLeft: Radius.circular(18),
                              )
                            : const BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
                                bottomRight: Radius.circular(18),
                              );

                        return GestureDetector(
                          onLongPress: () {
                            // set reply state like Instagram
                            setState(() {
                              _replyToMessageId = doc.id;
                              _replyToText = text;
                              _replyToSenderId = msg["senderId"];
                            });
                          },
                          child: Align(
                            alignment: alignment,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bubbleColor,
                                    borderRadius: radius,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // reply preview inside bubble
                                      if (replyToText.isNotEmpty) ...[
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border(
                                              left: BorderSide(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (replyLabel != null)
                                                Text(
                                                  replyLabel,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              const SizedBox(height: 2),
                                              Text(
                                                replyToText,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white60,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      // actual message text
                                      Text(
                                        text,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ------------ INPUT BAR WITH REPLY PREVIEW ------------
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    border: Border(
                      top: BorderSide(color: Color(0xFF262626), width: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // reply preview above text field
                      if (_replyToMessageId != null &&
                          _replyToText != null &&
                          _replyToText!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: const Color(0xFF3797F0).withOpacity(0.9),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _replyToSenderId == currentUid
                                          ? 'You'
                                          : otherUsername,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _replyToText!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _replyToMessageId = null;
                                    _replyToText = null;
                                    _replyToSenderId = null;
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(color: Colors.white),
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                hintText: "Message...",
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.black, // no grey background
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF333333),
                                    width: 0.8,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF666666),
                                    width: 1,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF3797F0),
                              ),
                              child: const Icon(
                                Icons.arrow_upward,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
