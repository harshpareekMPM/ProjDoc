import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD7pGo8YNzYfB_4YpX08WFPI2QxoCncZ3c',
    appId: '1:891569494592:web:dfd25b7c827607cef41da5',
    messagingSenderId: '891569494592',
    projectId: 'projdoc-aab8e',
    authDomain: 'projdoc-aab8e.firebaseapp.com',
    storageBucket: 'projdoc-aab8e.firebasestorage.app',
    measurementId: 'G-F1G5620CRD',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD7pGo8YNzYfB_4YpX08WFPI2QxoCncZ3c',
    appId: '1:891569494592:web:dfd25b7c827607cef41da5',
    messagingSenderId: '891569494592',
    projectId: 'projdoc-aab8e',
    authDomain: 'projdoc-aab8e.firebaseapp.com',
    storageBucket: 'projdoc-aab8e.firebasestorage.app',
  );
}
