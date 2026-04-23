import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'screens/new_report_screen.dart';
import 'screens/history_screen.dart';
import 'screens/auth_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  try {
    await FirebaseMessaging.instance.requestPermission();
  } catch (_) {}
  runApp(const ProjectDocsApp());
}

class ProjectDocsApp extends StatelessWidget {
  const ProjectDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProjectDocs AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.5),
          headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F7FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEEEEF8)),
          ),
          color: Colors.white,
        ),
      ),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A14),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ),
          );
        }
        if (snap.data == null) return const AuthScreen();
        return const MainScaffold();
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  static const _screens = [NewReportScreen(), HistoryScreen()];

  @override
  void initState() {
    super.initState();
    _saveFcmToken();
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  Future<void> _saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'fcm_token': token}, SetOptions(merge: true));
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'fcm_token': newToken}, SetOptions(merge: true));
      });
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body  = message.notification?.body ?? '';
    if (!mounted || (title.isEmpty && body.isEmpty)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x1A000000),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'ProjectDocs',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0A0A14),
                letterSpacing: -0.5,
              ),
            ),
            const Text(
              ' AI',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF6C63FF),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (user.photoURL != null)
            GestureDetector(
              onTap: () => _showProfileMenu(context, user),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  radius: 17,
                  backgroundImage: NetworkImage(user.photoURL!),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => _showProfileMenu(context, user),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFF6C63FF),
                child: Text(
                  (user.displayName ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEF8))),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFEDE9FF),
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF6C63FF)),
              label: 'Generate',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description_rounded,
                  color: Color(0xFF6C63FF)),
              label: 'My Reports',
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (user.photoURL != null)
              CircleAvatar(
                radius: 32,
                backgroundImage: NetworkImage(user.photoURL!),
              )
            else
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF6C63FF),
                child: Text(
                  (user.displayName ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              user.displayName ?? 'Student',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 18),
            ),
            Text(
              user.email ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  foregroundColor: Colors.red[600],
                  side: BorderSide(color: Colors.red.shade200),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  FirebaseAuth.instance.signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
