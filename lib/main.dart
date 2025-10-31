import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/home_page.dart';
import 'screens/login_screen.dart';
import 'screens/email_verify_screen.dart';
import 'db/db_helper.dart';
import 'services/custom_snackbar.dart';
import 'firebase_options.dart';
import 'providers/mcq_provider.dart';

/// 🔹 Global ScaffoldMessengerKey
final GlobalKey<ScaffoldMessengerState> globalMessengerKey =
GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase initialize
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Firestore offline cache
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 20 * 1024 * 1024, // 20 MB
  );

  runApp(const McqVaultApp());
}

/// 🔹 Root Application
class McqVaultApp extends StatelessWidget {
  const McqVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MCQProvider>(create: (_) => MCQProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: globalMessengerKey,
        title: 'MCQ Vault',
        theme: ThemeData(primarySwatch: Colors.deepPurple),
        home: const WifiListenerWrapper(child: AuthGate()),
      ),
    );
  }
}

/// 🔹 Wi-Fi/Data connectivity listener
class WifiListenerWrapper extends StatefulWidget {
  final Widget child;
  const WifiListenerWrapper({super.key, required this.child});

  @override
  State<WifiListenerWrapper> createState() => _WifiListenerWrapperState();
}

class _WifiListenerWrapperState extends State<WifiListenerWrapper> {
  final Connectivity _connectivity = Connectivity();
  final DBHelper _dbHelper = DBHelper();
  bool _wasOffline = false;

  // 🔹 Correct StreamSubscription type
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription =
        _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
          if (!mounted) return;

          // ✅ First result
          final result = results.isNotEmpty ? results.first : ConnectivityResult.none;

          // ❌ Went offline
          if (result == ConnectivityResult.none && !_wasOffline) {
            _wasOffline = true;
            CustomSnackbar.show(
              globalMessengerKey.currentContext!,
              "❌ No Internet connection",
              backgroundColor: Colors.redAccent,
            );
          }

          // 🌐 Came online
          else if (result != ConnectivityResult.none && _wasOffline) {
            _wasOffline = false;
            String connectionType = result == ConnectivityResult.wifi
                ? '📶 Wi-Fi connected'
                : '📱 Mobile data connected';

            CustomSnackbar.show(
              globalMessengerKey.currentContext!,
              connectionType,
              backgroundColor: Colors.green,
            );

            // 🔄 Sync local → Firestore
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              Future.microtask(() async {
                try {
                  await _dbHelper.syncToFirestore();       // No arguments needed
                  await _dbHelper.syncFromFirestore();     // No arguments needed
                  final mcqProvider =
                  Provider.of<MCQProvider>(context, listen: false);
                  await mcqProvider.loadMCQs();
                  debugPrint('✅ Local MCQs synced to Firestore for ${user.uid}');
                } catch (e) {
                  debugPrint('❌ Sync failed: $e');
                }
              });
            }
          }
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 🔹 Authentication Gate
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          if (!user.emailVerified) return const EmailVerifyScreen();
          return const HomePage();
        }

        return const LoginScreen();
      },
    );
  }
}
