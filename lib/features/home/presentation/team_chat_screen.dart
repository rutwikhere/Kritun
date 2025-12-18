import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'team_detail_screen.dart';

class TeamChatScreen extends StatefulWidget {
  final String teamId;

  const TeamChatScreen({super.key, required this.teamId});

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String teamName = "Team";
  bool _loadingTeam = true;

  // ---------- REPLY STATE ----------
  String? _replyToMessageId;
  String? _replyToUsername;
  String? _replyToText;

  @override
  void initState() {
    super.initState();
    _loadTeamName();
  }

  Future<void> _loadTeamName() async {
    final doc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .get();

    setState(() {
      teamName = (doc.data()?['name'] ?? "Team").toString();
      _loadingTeam = false;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messages() {
    return FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final username = userDoc.data()?['username'] ?? "User";
    final avatar = userDoc.data()?['avatarUrl'] ?? "";

    final chatRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('chat');

    final newDoc = chatRef.doc();

    await newDoc.set({
      'id': newDoc.id,
      'uid': user.uid,
      'username': username,
      'avatar': avatar,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
      // reply metadata (nullable)
      'replyToMessageId': _replyToMessageId,
      'replyToUsername': _replyToUsername,
      'replyToText': _replyToText,
    });

    _controller.clear();

    // clear reply state after send
    setState(() {
      _replyToMessageId = null;
      _replyToUsername = null;
      _replyToText = null;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------
  //  INSTAGRAM-STYLE BUBBLE WIDGET (avatar + name layout + reply)
  // ----------------------------------------------------
  Widget _messageBubble({
    required bool isMe,
    required bool showAvatar,
    required bool showUsername,
    required String username,
    required String avatar,
    required String text,
    required VoidCallback onLongPress,
    String? replyToUsername,
    String? replyToText,
  }) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            // ----------- LEFT SIDE (OTHER USER AVATAR) -----------
            if (!isMe) ...[
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: showAvatar
                    ? CircleAvatar(
                        radius: 18,
                        backgroundImage: avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : null,
                        backgroundColor: Colors.grey[800],
                        child: avatar.isEmpty
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
                      )
                    // keep spacing for grouped messages
                    : const SizedBox(width: 36),
              ),
            ],

            // ----------- USERNAME ABOVE BUBBLE & THE BUBBLE -----------
            Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // top username (only on first message of group)
                if (showUsername && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      username,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // ----------- MESSAGE BUBBLE -----------
                Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF1A73E8)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 16 : 4),
                      topRight: Radius.circular(isMe ? 4 : 16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // reply preview inside bubble (quoted message)
                      if (replyToText != null && replyToText.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: Colors.white.withOpacity(0.6),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (replyToUsername != null &&
                                  replyToUsername.isNotEmpty)
                                Text(
                                  replyToUsername,
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
                          fontSize: 15,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _loadingTeam || teamName.isEmpty ? 'Team' : teamName;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              child: Text(
                initial,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Team info',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TeamDetailScreen(teamId: widget.teamId),
                ),
              );
            },
          ),
        ],
      ),

      // ================= BODY =================
      body: Column(
        children: [
          // --------- MESSAGES ----------
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messages(),
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
                      "No messages yet.\nSay hi to your team 👋",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final currentUid = FirebaseAuth.instance.currentUser?.uid;

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data();
                    final isMe = data['uid'] == currentUid;
                    final username = (data['username'] ?? '').toString();
                    final avatar = (data['avatar'] ?? '').toString();
                    final text = (data['message'] ?? '').toString();

                    final replyToUsername = (data['replyToUsername'] ?? '')
                        .toString();
                    final replyToText = (data['replyToText'] ?? '').toString();

                    // because reverse:true, OLDER message (earlier in time) is at index + 1
                    Map<String, dynamic>? prevMessage;
                    if (index < messages.length - 1) {
                      prevMessage = messages[index + 1].data();
                    }

                    // because reverse:true, NEWER message (later in time) is at index - 1
                    Map<String, dynamic>? nextMessage;
                    if (index > 0) {
                      nextMessage = messages[index - 1].data();
                    }

                    // first message in this user's consecutive block (oldest in the group)
                    final isFirstInGroup =
                        prevMessage == null ||
                        prevMessage['uid'] != data['uid'];

                    // last message in this user's consecutive block (latest in the group)
                    final isLastInGroup =
                        nextMessage == null ||
                        nextMessage['uid'] != data['uid'];

                    // avatar on LAST message of the group
                    final showAvatar = !isMe && isLastInGroup;

                    // username on FIRST message of the group
                    final showUsername = !isMe && isFirstInGroup;

                    return _messageBubble(
                      isMe: isMe,
                      showAvatar: showAvatar,
                      showUsername: showUsername,
                      username: username,
                      avatar: avatar,
                      text: text,
                      replyToUsername: replyToUsername.isEmpty
                          ? null
                          : replyToUsername,
                      replyToText: replyToText.isEmpty ? null : replyToText,
                      onLongPress: () {
                        // set reply state
                        setState(() {
                          _replyToMessageId = doc.id;
                          _replyToUsername = username;
                          _replyToText = text;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          // --------- INPUT BAR (with reply preview) ----------
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 6.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply preview above input
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
                            color: Colors.blueAccent.withOpacity(0.9),
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
                                  _replyToUsername ?? 'User',
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
                                _replyToUsername = null;
                                _replyToText = null;
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
                            hintText: "Message...",
                            hintStyle: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Colors.black,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Colors.white24,
                                width: 0.8,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Colors.white70,
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
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueAccent,
                          ),
                          child: const Icon(
                            Icons.send,
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
  }
}
