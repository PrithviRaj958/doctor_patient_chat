
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatpage.dart';

class PatientHomePage extends StatelessWidget {
  const PatientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 69, 237, 190),
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 32),
            const SizedBox(width: 8),
            const Text('Patient Dashboard'),
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

      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Doctor')
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final doctors = snapshot.data!.docs;

          if (doctors.isEmpty) {
            return const Center(child: Text('No doctors available'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doc = doctors[index];
              final doctorId = doc.id;
              final name = doc['name'] ?? '';
final specialization = doc['specialization'] ?? '';
final displayName = specialization.isNotEmpty
    ? '$name (${specialization})'
    : name;

              final chatId = generateChatId(currentUid, doctorId);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade300,
                    child: Text(
  name.isNotEmpty ? name[0].toUpperCase() : '?',
),

                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Tap to chat"),
                  trailing: const Icon(Icons.chat_bubble_outline),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          chatId: chatId,
                          receiverId: doctorId,
                          receiverEmail: displayName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String generateChatId(String a, String b) =>
      a.hashCode <= b.hashCode ? '$a\_$b' : '$b\_$a';
}
