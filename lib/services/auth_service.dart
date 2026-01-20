import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');
      print('Platform: ${kIsWeb ? "Web" : "Mobile"}');
      
      if (kIsWeb) {
        // Web-specific sign-in using popup
        print('Using web popup sign-in');
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        
        final result = await _auth.signInWithPopup(googleProvider);
        print('Successfully signed in to Firebase: ${result.user?.email}');
        return result;
      } else {
        // Mobile sign-in using google_sign_in package
        print('Using mobile sign-in');
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          print('User cancelled Google Sign-In');
          return null;
        }

        print('Google user signed in: ${googleUser.email}');
        
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        print('Got authentication tokens');
        
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        print('Signing in to Firebase...');
        final result = await _auth.signInWithCredential(credential);
        print('Successfully signed in to Firebase: ${result.user?.email}');
        return result;
      }
    } catch (e, stackTrace) {
      print('Error signing in with Google: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}
