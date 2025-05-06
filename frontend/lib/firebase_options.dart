import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDdk-4Q0njrTxhQaXmYLE2044CBegiJ4vg',
    appId: '1:869090399817:web:0601f5008cd277912c5198',
    messagingSenderId: '869090399817',
    projectId: 'cer4absense',
    authDomain: 'cer4absense.firebaseapp.com',
    storageBucket: 'cer4absense.firebasestorage.app',
  );

  // Substitua estas configurações com suas próprias quando tiver os valores reais

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGRXcqMnPLhmGmF-8JKMndSjM3B2TJHt0',
    appId: '1:869090399817:android:83e8998f426338952c5198',
    messagingSenderId: '869090399817',
    projectId: 'cer4absense',
    storageBucket: 'cer4absense.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCdk6lpdumhu6uT-hE4yhugRmRAoTNiAaU',
    appId: '1:869090399817:ios:c6521c95d42747012c5198',
    messagingSenderId: '869090399817',
    projectId: 'cer4absense',
    storageBucket: 'cer4absense.firebasestorage.app',
    iosBundleId: 'com.absencer4.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeySample123456789',
    appId: '1:123456789012:macos:abc123def456',
    messagingSenderId: '123456789012',
    projectId: 'ceriv-app',
    storageBucket: 'ceriv-app.appspot.com',
    iosClientId: 'sample-ios-client-id.apps.googleusercontent.com',
    iosBundleId: 'com.example.cerivApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeySample123456789',
    appId: '1:123456789012:windows:abc123def456',
    messagingSenderId: '123456789012',
    projectId: 'ceriv-app',
    storageBucket: 'ceriv-app.appspot.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeySample123456789',
    appId: '1:123456789012:linux:abc123def456',
    messagingSenderId: '123456789012',
    projectId: 'ceriv-app',
    storageBucket: 'ceriv-app.appspot.com',
  );
}