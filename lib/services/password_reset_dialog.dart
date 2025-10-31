import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'custom_snackbar.dart';

class PasswordResetDialog {
  static Future<void> show(BuildContext context) async {
    final emailController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text("🔐 Reset Password",
              style: TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.bold,
              )),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Enter your email",
              prefixIcon: Icon(Icons.email, color: Colors.deepPurple),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) {
                  CustomSnackbar.show(context,
                      "⚠️ Please enter your email!",
                      backgroundColor: Colors.red);
                  return;
                }

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: email);
                  if (context.mounted) {
                    Navigator.pop(context);
                    CustomSnackbar.show(
                        context,
                        "✅ Password reset link sent!\nCheck your email.",
                        backgroundColor: Colors.green);
                  }
                } catch (e) {
                  CustomSnackbar.show(
                      context, "❌ Error: ${e.toString()}",
                      backgroundColor: Colors.red);
                }
              },
              child: const Text("Send",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
