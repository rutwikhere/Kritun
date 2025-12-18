import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kritun/features/home/presentation/player_profile_screen.dart';

class ConnectionsListScreen extends StatelessWidget {
  final String uid;

  const ConnectionsListScreen({super.key, required this.uid});

  Stream<QuerySnapshot<Map<String, dynamic>>> _connectionsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('connections')
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadUser(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  Future<void> _removeConnection(
    BuildContext context,
    String myUid,
    String otherUid,
  ) async {
    try {
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connection removed')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove connection')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connections")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _connectionsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return const Center(child: Text("Failed to load connections"));
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No connections yet.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final c = docs[index].data();
              final targetUid = (c['uid'] ?? '').toString();
              final status = (c['status'] ?? '').toString();

              if (targetUid.isEmpty) {
                return const SizedBox.shrink();
              }

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _loadUser(targetUid),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(title: Text("Loading..."));
                  }

                  if (!userSnap.data!.exists) {
                    return ListTile(
                      title: Text("Unknown user ($targetUid)"),
                      trailing: TextButton(
                        onPressed: () =>
                            _removeConnection(context, uid, targetUid),
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }

                  final u = userSnap.data!.data()!;
                  final username = (u['username'] ?? 'Unknown').toString();
                  final avatar = (u['avatarUrl'] ?? '').toString();

                  String subtitle;
                  if (status == 'connected') {
                    subtitle = 'Connected';
                  } else if (status == 'pending') {
                    subtitle = 'Request sent';
                  } else if (status == 'requested') {
                    subtitle = 'Requested you';
                  } else {
                    subtitle = status;
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar.isNotEmpty
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(username),
                    subtitle: Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlayerProfileScreen(userId: targetUid),
                        ),
                      );
                    },
                    trailing: TextButton(
                      onPressed: () =>
                          _removeConnection(context, uid, targetUid),
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
