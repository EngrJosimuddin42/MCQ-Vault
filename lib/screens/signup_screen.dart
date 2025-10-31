import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_verify_screen.dart';
import '../services/custom_snackbar.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 🔹 Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  // 🔹 State Variables
  bool isLoading = false;
  bool _obscurePassword = true;
  String? emailError;
  String? passwordError;

  // ✅ Email validation
  void _validateEmail(String value) {
    if (value.contains(RegExp(r'[A-Z]'))) {
      setState(() => emailError =
      "❌ Email must be lowercase (no capital letters allowed)");
    } else if (!RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$')
        .hasMatch(value)) {
      setState(() =>
      emailError = "❌ Invalid email format (e.g. example@gmail.com)");
    } else {
      setState(() => emailError = null);
    }
  }

  // ✅ Password validation
  void _validatePassword(String value) {
    if (value.isEmpty) {
      setState(() => passwordError = "❌ Password is required");
    } else if (value.length < 6) {
      setState(() => passwordError = "🔒 At least 6 characters required");
    } else if (!RegExp(r'[0-9]').hasMatch(value)) {
      setState(() => passwordError = "🔢 Must contain at least one number");
    } else if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      setState(() => passwordError = "🅰️ Must contain at least one letter");
    } else {
      setState(() => passwordError = null);
    }
  }

  // ✅ Signup function
  Future<void> signUp() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      CustomSnackbar.show(
        context,
        "⚠️ Please fill all fields before signup!",
        backgroundColor: Colors.red,
      );
      return;
    }

    if (emailError != null || passwordError != null) {
      CustomSnackbar.show(
        context,
        "⚠️ Please fix the highlighted errors first!",
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 🔹 Create user
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) throw Exception("User creation failed!");

      // 🔹 Save user info to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'verified': false,
      });

      // 🔹 Send verification email
      await user.sendEmailVerification();

      // 🔹 Small delay + reload
      await Future.delayed(const Duration(seconds: 1));
      await user.reload();

      if (!mounted) return;

      CustomSnackbar.show(
        context,
        "✅ Signup successful! Verification email sent.",
        backgroundColor: Colors.green,
      );

      // ✅ Navigate to verify screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmailVerifyScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = "⚠️ This email is already registered.";
          break;
        case 'invalid-email':
          message = "⚠️ Invalid email format!";
          break;
        case 'weak-password':
          message = "⚠️ Password must be at least 6 characters.";
          break;
        default:
          message = "⚠️ Signup failed: ${e.message}";
      }
      CustomSnackbar.show(context, message, backgroundColor: Colors.red);
    } catch (e) {
      CustomSnackbar.show(
        context,
        "⚠️ Unexpected error: $e",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  "Create Your Account",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 25),

                // 🔹 Name Field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 🔹 Email Field
                TextField(
                  controller: emailController,
                  onChanged: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: emailError,
                  ),
                ),
                const SizedBox(height: 15),

                // 🔹 Password Field
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  onChanged: _validatePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: passwordError,
                  ),
                ),
                const SizedBox(height: 25),

                // 🔹 Sign Up Button
                isLoading
                    ? const CircularProgressIndicator(color: Colors.deepPurple)
                    : ElevatedButton(
                  onPressed: signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 60, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 15),

                // 🔹 Login Navigation
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Already have an account? Log In",
                    style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
