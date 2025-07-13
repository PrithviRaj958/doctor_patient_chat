
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatpage.dart';

class DoctorHomePage extends StatelessWidget {
  const DoctorHomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
  title: Row(
    children: [
      Image.asset(
        'assets/logo.png',
        height: 32,
      ),
      const SizedBox(width: 8),
      const Text('Doctor Dashboard'),
    ],
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () async {
         print('🔴 Logging out...');
      await FirebaseAuth.instance.signOut();
  
},

    ),
  ],
),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final chats = snap.data!.docs;
          final patientIds = chats
              .map((doc) => doc.id.split('_'))
              .where((parts) => parts.length == 2)
              .map((parts) {
                if (parts[0] == currentUid) return parts[1];
                if (parts[1] == currentUid) return parts[0];
                return null;
              })
              .whereType<String>()
              .toSet();
          if (patientIds.isEmpty) return const Center(child: Text('No patient messages yet.'));
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: patientIds.toList())
                .get(),
            builder: (context, userSnap) {
              if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
              return ListView(
                padding: const EdgeInsets.all(8),
                children: userSnap.data!.docs.map((patient) {
                  final pid = patient.id;
                  final email = patient['email'] ?? '';
                  final chatId = generateChatId(currentUid, pid);
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('chats').doc(chatId).get(),
                    builder: (context, chatSnap) {
                      final chatData = chatSnap.data?.data() as Map<String, dynamic>? ?? {};
                      final lastMsg = chatData['lastMessage'] ?? 'Tap to reply';
                      final lastUpdated = chatData['lastUpdated']?.toDate();
                      return FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('chats')
                            .doc(chatId)
                            .collection('messages')
                            .where('unreadBy', arrayContains: currentUid)
                            .get(),
                        builder: (context, unreadSnap) {
                          final unreadCount = unreadSnap.data?.docs.length ?? 0;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                  backgroundColor: Colors.teal.shade200,
                                  child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?')),
                              title: Text(email,
                                  style: TextStyle(
                                      fontWeight:
                                          unreadCount > 0 ? FontWeight.bold : FontWeight.normal)),
                              subtitle: Text(lastMsg,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (lastUpdated != null)
                                    Text(formatTimeAgo(lastUpdated),
                                        style:
                                            const TextStyle(fontSize: 12, color: Colors.grey)),
                                  if (unreadCount > 0)
                                    const Icon(Icons.mark_email_unread,
                                        color: Colors.redAccent, size: 20),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatPage(
                                      chatId: chatId,
                                      receiverId: pid,
                                      receiverEmail: email,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  String generateChatId(String a, String b) =>
      a.hashCode <= b.hashCode ? '$a\_$b' : '$b\_$a';

  String formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
