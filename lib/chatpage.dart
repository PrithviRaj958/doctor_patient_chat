import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String receiverEmail;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.receiverEmail,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final messageController = TextEditingController();
  final firestore = FirebaseFirestore.instance;

  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    messageController.addListener(_onTextChanged);
    _markRead();
  }

  void _markRead() async {
    final docs = await firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('unreadBy', arrayContains: user.uid)
        .get();
    for (final d in docs.docs) {
      await d.reference.update({
        'unreadBy': FieldValue.arrayRemove([user.uid]),
      });
    }
  }

  void sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    await firestore.collection('chats').doc(widget.chatId).set({
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastMessage': text,
      'typingStatus': {},
    }, SetOptions(merge: true));
    await firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'unreadBy': [widget.receiverId],
    });
    messageController.clear();
    _updateTyping(false);
  }

  void _onTextChanged() {
    _typingTimer?.cancel();
    if (!_isTyping) _updateTyping(true);
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _updateTyping(false);
    });
  }

  void _updateTyping(bool typing) {
    _isTyping = typing;
    firestore.collection('chats').doc(widget.chatId).set({
      'typingStatus': {user.uid: typing},
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _updateTyping(false);
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesRef = firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp');

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: firestore.collection('users').doc(widget.receiverId).snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
            final name = data.containsKey('name') ? data['name'] : widget.receiverEmail;
            final specialization = data['specialization'] ?? '';
            final displayName = specialization.isNotEmpty ? '$name ($specialization)' : name;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName),
                StreamBuilder<DocumentSnapshot>(
                  stream: firestore.collection('chats').doc(widget.chatId).snapshots(),
                  builder: (context, typingSnap) {
                    final chatData = typingSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final typing = chatData['typingStatus'] as Map<String, dynamic>? ?? {};
                    final isTyping = typing[widget.receiverId] == true;
                    return isTyping
                        ? const Text(
                            'Typing...',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          )
                        : const SizedBox();
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Clear Chat?'),
                      content: const Text('Delete all messages in this chat?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (confirmed) {
                final msgs = await messagesRef.get();
                for (var d in msgs.docs) await d.reference.delete();
                await firestore.collection('chats').doc(widget.chatId).update({
                  'lastMessage': '',
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: messagesRef.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Expanded(child: Center(child: CircularProgressIndicator()));
              }
              final docs = snap.data!.docs;
              return Expanded(
                child: ListView(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: docs.reversed.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final owns = data['senderId'] == user.uid;
                    return Align(
                      alignment: owns ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: owns
                            ? () async {
                                final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Delete this message?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                                if (confirm) await doc.reference.delete();
                              }
                            : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: owns ? Colors.teal.shade300 : Colors.grey.shade300,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(owns ? 16 : 0),
                              bottomRight: Radius.circular(owns ? 0 : 16),
                            ),
                          ),
                          child: Text(
                            data['text'] ?? '',
                            style: TextStyle(color: owns ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    onChanged: (_) => _onTextChanged(),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.teal),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.teal, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
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
