import 'package:flutter/material.dart';

class CustomSnackbar {
  static void show(BuildContext context, String message, {Color backgroundColor = Colors.deepPurple}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center,style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}