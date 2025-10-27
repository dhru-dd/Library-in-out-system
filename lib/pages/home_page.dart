import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:porject2/pages/landing_page.dart';
import 'package:porject2/pages/record_page.dart';
import 'package:porject2/pages/scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isInLibrary = false;
  final user = FirebaseAuth.instance.currentUser;
  String userName = "Student Name";
  DateTime? lastPressed; // For double back to exit

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLibraryStatus();
  }

  /// Load user's name from Firestore
  Future<void> _loadUserData() async {
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        if (doc.exists) {
          setState(() {
            userName = doc['name'] ?? "Student Name";
          });
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
      }
    }
  }

  /// Load library status (IN/OUT) from Firestore
  Future<void> _loadLibraryStatus() async {
    if (user != null) {
      try {
        final statusDoc = await FirebaseFirestore.instance
            .collection('libraryStatus')
            .doc(user!.uid)
            .get();
        if (statusDoc.exists) {
          setState(() {
            isInLibrary = statusDoc['inLibrary'] ?? false;
          });
        }
      } catch (e) {
        debugPrint("Error loading library status: $e");
      }
    }
  }

  /// Logout and navigate to Starting page
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const StartingPage()),
        (route) => false,
      );
    }
  }

  /// Handle double back press to exit
  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (lastPressed == null ||
        now.difference(lastPressed!) > const Duration(seconds: 2)) {
      lastPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Press back again to exit"),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Library In–Out System"),
          centerTitle: true,
          backgroundColor: Colors.deepPurple,
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.deepPurple),
                accountName: Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(
                  user?.email ?? "No email available",
                  style: const TextStyle(color: Colors.white70),
                ),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.deepPurple),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("My In–Out History"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RecordsPage()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Logout"),
                onTap: _logout,
              ),
            ],
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isInLibrary ? Icons.check_circle : Icons.cancel,
                color: isInLibrary ? Colors.green : Colors.red,
                size: 90,
              ),
              const SizedBox(height: 20),
              Text(
                isInLibrary
                    ? "You are currently IN the Library"
                    : "No active session",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isInLibrary ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isInLibrary
                    ? "Scan QR to mark OUT when you leave."
                    : "Scan QR to mark IN when you enter.",
                style: const TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.deepPurple,
          icon: const Icon(Icons.qr_code_2, size: 28, color: Colors.white),
          label: const Text("Scan QR", style: TextStyle(color: Colors.white)),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ScanPage()),
            );
            if (!mounted) return;
            if (result == 'in') {
              setState(() => isInLibrary = true);
            } else if (result == 'out') {
              setState(() => isInLibrary = false);
            }
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
