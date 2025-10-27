import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool isProcessing = false;

  Future<void> handleScan(String code) async {
    if (isProcessing) return; // prevent multiple scans
    isProcessing = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please log in first.")));
      Navigator.pop(context);
      return;
    }

    // Only accept "IN" or "OUT" codes
    if (code != 'IN' && code != 'OUT') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid QR code.")));
      Navigator.pop(context);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // 🔹 Fetch user's name & roll no safely
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("User data not found.")));
        Navigator.pop(context);
        return;
      }
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Unknown';
      final userRoll = userData['rollno'] ?? 'Unknown';

      final statusDoc = await firestore
          .collection('libraryStatus')
          .doc(user.uid)
          .get();
      final currentlyInLibrary = statusDoc.exists
          ? statusDoc['inLibrary'] ?? false
          : false;

      if ((currentlyInLibrary && code == 'IN') ||
          (!currentlyInLibrary && code == 'OUT')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyInLibrary
                  ? "You are already in the library"
                  : "You have already left the library",
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
        return;
      }

      // 🔹 Update library status
      await firestore.collection('libraryStatus').doc(user.uid).set({
        'inLibrary': code == 'IN',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 🔹 Add a record in "records" collection
      await firestore.collection('records').add({
        'userId': user.uid,
        'email': user.email,
        'name': userName,
        'rollno': userRoll,
        'action': code == 'IN' ? 'Entered Library' : 'Left Library',
        'timestamp': FieldValue.serverTimestamp(),
        'status': code, // optional for easier display in history
      });

      // 🔹 Feedback message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code == 'IN'
                ? "Marked as IN successfully!"
                : "Marked as OUT successfully!",
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Return result to HomePage
      Navigator.pop(context, code.toLowerCase());
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
      Navigator.pop(context);
    } finally {
      isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        backgroundColor: Colors.deepPurple,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final String? code = barcode.rawValue;
            if (code != null) {
              handleScan(code.trim().toUpperCase());
              break;
            }
          }
        },
      ),
    );
  }
}
