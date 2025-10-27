import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  // ✅ Fetch records directly from "records" collection
  Future<List<Map<String, dynamic>>> fetchRecords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    // Query from the main 'records' collection
    final query = await FirebaseFirestore.instance
        .collection('records')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();

    return query.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My In–Out History"),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading records"));
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return const Center(
              child: Text(
                "No records found.",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final action = record['action'] ?? 'Unknown';
              final name = record['name'] ?? 'Unknown';
              final rollno = record['rollno'] ?? 'Unknown';
              final timestamp = (record['timestamp'] as Timestamp?)?.toDate();

              final formattedTime = timestamp != null
                  ? DateFormat('EEE, MMM d, yyyy • hh:mm a').format(timestamp)
                  : 'Unknown time';

              final isIn = action.contains('Entered');

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isIn ? Colors.green : Colors.red,
                    child: Icon(
                      isIn ? Icons.login : Icons.logout,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    "$action — $formattedTime",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isIn ? Colors.green[700] : Colors.red[700],
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("Name: $name"),
                      Text("Roll No: $rollno"),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
