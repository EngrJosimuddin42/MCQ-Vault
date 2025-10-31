import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/custom_snackbar.dart';
import '../services/alert_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isUploading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() {
          userData = null;
          isLoading = false;
        });
        CustomSnackbar.show(context, "⚠️ No profile data found!", backgroundColor: Colors.orange);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "❌ Error loading profile: $e";
        isLoading = false;
      });
      CustomSnackbar.show(context,"❌ Failed to load profile. Please try again later.",backgroundColor: Colors.red);
    }
  }

  Future<void> uploadProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => isUploading = true);

    try {
      final ref = FirebaseStorage.instance.ref().child('profile_images').child('${user!.uid}.jpg');
      await ref.putFile(File(pickedFile.path));
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'photoUrl': imageUrl});

      setState(() {
        userData!['photoUrl'] = imageUrl;
        isUploading = false;
      });

      CustomSnackbar.show(context, "✅ Profile photo updated");
    } catch (e) {
      setState(() => isUploading = false);
      CustomSnackbar.show(context, "❌ Error: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _showEditProfileDialog(BuildContext context, Map<String, dynamic>? userData, String userId, Function(Map<String, dynamic>) onProfileUpdated) async {
    final nameController = TextEditingController(text: userData?['name']);
    final phoneController = TextEditingController(text: userData?['phone']);

    final confirm = await AlertDialogUtils.showConfirm(
      context: context,
      title: "Edit Profile",
      confirmText: "Save",
      cancelText: "Cancel",
      confirmColor: Colors.deepPurple,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Name",
              prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: "Phone Number",
              prefixIcon: Icon(Icons.phone, color: Colors.deepPurple),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );

    if (confirm == true) {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();

      if (name.isEmpty || phone.isEmpty) {
        CustomSnackbar.show(context,"⚠️ Please fill all fields!", backgroundColor: Colors.orange);
        return;
      }
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'name': name,
          'phone': phone,
        });

        onProfileUpdated({
          'name': name,
          'phone': phone,
        });
        CustomSnackbar.show(context,"✅ Profile updated successfully!", backgroundColor: Colors.green);
      } catch (e) {
        CustomSnackbar.show(context,"❌ Error updating profile. Please try again later.", backgroundColor: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (errorMessage != null) return _buildErrorWidget();
    if (userData == null) return const Scaffold(body: Center(child: Text("No profile data found")));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      appBar: AppBar(
        title: const Text("Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {Navigator.pop(context);},
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileAvatar(),
            const SizedBox(height: 20),
            Text(userData!['name'] ?? 'No Name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 6),
            Text(user!.email ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 20),
            if (userData!['phone'] != null) _buildPhoneRow(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                await _showEditProfileDialog(context, userData, user!.uid, (updatedData) {
                  setState(() {
                    userData!['name'] = updatedData['name'];
                    userData!['phone'] = updatedData['phone'];
                  });
                });
              },
            ),
            const SizedBox(height: 20),
            const Divider(thickness: 1, color: Colors.black, indent: 20, endIndent: 20),
            const SizedBox(height: 20),
            // About / Account Info / Tips
            _buildProfileDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: loadProfile, child: const Text("Retry"))
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 65,
            backgroundColor: Colors.deepPurple.shade100,
            backgroundImage: userData!['photoUrl'] != null ? NetworkImage(userData!['photoUrl']) : null,
            child: userData!['photoUrl'] == null
                ? Text(userData!['name'][0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.deepPurple, fontWeight: FontWeight.bold))
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: InkWell(
              onTap: uploadProfileImage,
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple))
                    : const Icon(Icons.camera_alt, color: Colors.deepPurple),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "About",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
        ),
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Welcome to your personal account! Here you can manage your profile safely and efficiently:",
              style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
            ),
            SizedBox(height: 6),
            Text("• Update your name and phone number anytime.", style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
            Text("• Change or upload a profile photo to personalize your account.", style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
            Text("• Review your account information regularly for smooth usage.", style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          "Tips",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
        ),
        const SizedBox(height: 6),
        const Text(
          "✅ Keep your profile photo updated.\n"
              "✅ Make sure your phone number is valid.\n"
              "✅ Regularly check your account details for any changes.\n"
              "✅ Use a strong password to protect your account.\n"
              "✅ Keep your email address updated.\n"
              "✅ Contact support if you notice any suspicious activity.",
          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildPhoneRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.phone, color: Colors.deepPurple),
        const SizedBox(width: 8),
        Text(userData!['phone'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
      ],
    );
  }
}
