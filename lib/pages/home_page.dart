import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Libtrack/pages/landing_page.dart';
import 'package:Libtrack/pages/record_page.dart';
import 'package:Libtrack/pages/scan_page.dart';

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
        backgroundColor: Colors.grey[900], // Dark background
        appBar: AppBar(
          iconTheme: IconThemeData(color: Colors.white),
          title: const Text(
            "Library In–Out System",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.blueGrey[700], // subtle dark color
          elevation: 0,
        ),
        drawer: Drawer(
          child: Container(
            color: Colors.grey[850], // dark drawer
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[800], // subtle elegant color
                  ),
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
                    child: Icon(Icons.person, size: 40, color: Colors.blueGrey),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.white70),
                  title: const Text(
                    "My In–Out History",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RecordsPage()),
                    );
                  },
                ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white70),
                  title: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isInLibrary ? Colors.green[400] : Colors.red[400],
                ),
                padding: const EdgeInsets.all(20),
                child: Icon(
                  isInLibrary ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                  size: 55,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isInLibrary
                    ? "You are currently IN the Library"
                    : "No active session",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isInLibrary ? Colors.green[300] : Colors.red[300],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isInLibrary
                    ? "Scan QR to mark OUT when you leave."
                    : "Scan QR to mark IN when you enter.",
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
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
          backgroundColor: Colors.blueGrey[700], // elegant color
          icon: const Icon(Icons.qr_code_2, color: Colors.white),
          label: const Text("Scan QR", style: TextStyle(color: Colors.white)),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
