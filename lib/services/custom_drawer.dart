import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';
import '../services/alert_dialog.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 🔹 Drawer Header with Back button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Menu",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 Drawer Menu Items
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.account_circle,
                      color: Colors.deepPurple,
                      title: "Profile",
                      subtitle: "Standard User",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.language,
                      color: Colors.orange,
                      title: "Language",
                      subtitle: "English",
                    ),
                    _buildMenuItem(
                      icon: Icons.location_on_outlined,
                      color: Colors.red,
                      title: "Location",
                      subtitle: "Bangladesh",
                    ),
                    _buildMenuItem(
                      icon: Icons.settings,
                      color: Colors.blueAccent,
                      title: "Settings",
                      subtitle: "Manage preferences",
                    ),
                    _buildMenuItem(
                      icon: Icons.help_outline,
                      color: Colors.purple,
                      title: "Help & Support",
                      subtitle: "Get assistance",
                    ),
                    _buildMenuItem(
                      icon: Icons.feedback,
                      color: Colors.brown,
                      title: "Send Feedback",
                      subtitle: "Share your experience",
                    ),

                    const SizedBox(height: 12),
                    const Divider(thickness: 1, indent: 16, endIndent: 16),
                    const SizedBox(height: 12),

                    _buildLogoutItem(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Drawer Menu Item
  Widget _buildMenuItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: onTap, // ✅ Tap behavior
        ),
      ),
    );
  }

  // 🔹 Logout Item
  Widget _buildLogoutItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text(
            "Log Out",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          onTap: () async {
            final shouldLogout = await AlertDialogUtils.showConfirm(
              context: context,
              title: "Confirm Logout",
              content: const Text("Are you sure you want to log out?"),
              confirmColor: Colors.red,
            );

            if (shouldLogout == true) {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
