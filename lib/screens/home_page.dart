import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/mcq_provider.dart';
import '../screens/create_question.dart';
import '../screens/update_database.dart';
import '../screens/profile_screen.dart';
import '../services/custom_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isProfileLoading = true;
  Map<String, dynamic>? profileData;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        profileData = doc.data();
      }
    }
    setState(() {
      isProfileLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ MCQProvider থেকে online/offline state নিলাম
    final mcqProvider = Provider.of<MCQProvider>(context);

    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('MCQ Vault Dashboard'),
        centerTitle: true,
        elevation: 4,
        leadingWidth: 60,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  mcqProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                  color:
                  mcqProvider.isOnline ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  mcqProvider.isOnline ? "Online" : "Offline",
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.school, size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    "Your Learning Companion",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 50),
                  _buildMenuButton(
                    context,
                    title: "Create Question",
                    icon: Icons.add_circle_outline,
                    color: Colors.green,
                    pageIndex: 0,
                  ),
                  const SizedBox(height: 20),
                  _buildMenuButton(
                    context,
                    title: "Update Database",
                    icon: Icons.update,
                    color: Colors.orange,
                    pageIndex: 1,
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required int pageIndex,
      }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MainLayout(startIndex: pageIndex)),
        );
      },
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withOpacity(0.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ PageView Layout
class MainLayout extends StatefulWidget {
  final int startIndex;
  const MainLayout({super.key, this.startIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late PageController pageController;
  late int selectedIndex;

  final List<Widget> pages = [
    const CreateQuestionScreen(),
    const UpdateDatabaseScreen(),
  ];

  final List<String> titles = [
    'Create Question',
    'Update Database',
  ];

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.startIndex;
    pageController = PageController(initialPage: widget.startIndex);
  }

  void onPageChanged(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: onPageChanged,
        children: pages,
      ),
    );
  }
}
