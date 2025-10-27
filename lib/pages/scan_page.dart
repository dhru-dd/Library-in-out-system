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
    setState(() => isProcessing = true);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.blueGrey),
      ),
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pop(); // remove loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please log in first."),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
      setState(() => isProcessing = false);
      return;
    }

    // Only accept "IN" or "OUT" codes
    if (code != 'IN' && code != 'OUT') {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid QR code."),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
      setState(() => isProcessing = false);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Fetch user data
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User data not found."),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
        setState(() => isProcessing = false);
        return;
      }

      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Unknown';
      final userRoll = userData['rollno'] ?? 'Unknown';

      // Check current library status
      final statusDoc = await firestore
          .collection('libraryStatus')
          .doc(user.uid)
          .get();
      final currentlyInLibrary = statusDoc.exists
          ? statusDoc['inLibrary'] ?? false
          : false;

      if ((currentlyInLibrary && code == 'IN') ||
          (!currentlyInLibrary && code == 'OUT')) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyInLibrary
                  ? "You are already in the library"
                  : "You have already left the library",
            ),
            backgroundColor: Colors.blueGrey[700],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
        setState(() => isProcessing = false);
        return;
      }

      // Update library status
      await firestore.collection('libraryStatus').doc(user.uid).set({
        'inLibrary': code == 'IN',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Add record in "records" collection
      await firestore.collection('records').add({
        'userId': user.uid,
        'email': user.email,
        'name': userName,
        'rollno': userRoll,
        'action': code == 'IN' ? 'Entered Library' : 'Left Library',
        'timestamp': FieldValue.serverTimestamp(),
        'status': code,
      });

      // Show success message
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code == 'IN'
                ? "Marked as IN successfully!"
                : "Marked as OUT successfully!",
          ),
          backgroundColor: Colors.blueGrey[700],
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Return result to HomePage
      Navigator.pop(context, code.toLowerCase());
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          "Scan QR Code",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey[700],
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
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
          // Scanner overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueGrey[300]!, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
