import 'package:flutter/material.dart';

class AlertDialogUtils {
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required Widget content,
    String confirmText = "Yes",
    String cancelText = "No",
    Color confirmColor = Colors.redAccent})
  {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: confirmColor)),
        content: content,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelText)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}