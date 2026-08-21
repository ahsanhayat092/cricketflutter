import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/firestore_paths.dart';
import '../models/app_user.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (_) {
    return Stream.value(null);
  }
});

final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AppUser>((ref) {
  return CurrentUserNotifier();
});

class CurrentUserNotifier extends StateNotifier<AppUser> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  CurrentUserNotifier()
      : super(const AppUser(
          uid: 'guest',
          email: '',
          role: 'public', // Default to public viewer for read-only security
        )) {
    _initListener();
  }

  void _initListener() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          try {
            final doc = await FirebaseFirestore.instance
                .doc(FirestorePaths.user(user.uid))
                .get();
            if (doc.exists && doc.data() != null) {
              state = AppUser.fromMap(user.uid, doc.data());
            } else {
              // Derive role from email or default to scorer for authenticated users
              final userRole = _deriveRoleFromEmail(user.email ?? '');
              final newUser = AppUser(
                uid: user.uid,
                email: user.email ?? '',
                role: userRole,
              );
              state = newUser;
              // Save to Firestore
              await FirebaseFirestore.instance
                  .doc(FirestorePaths.user(user.uid))
                  .set(newUser.toMap(), SetOptions(merge: true));
            }
          } catch (_) {
            final userRole = _deriveRoleFromEmail(user.email ?? '');
            state = AppUser(
              uid: user.uid,
              email: user.email ?? '',
              role: userRole,
            );
          }
        } else {
          // Reset to public guest when logged out
          if (state.uid != 'guest' && !state.uid.startsWith('demo_')) {
            state = const AppUser(uid: 'guest', email: '', role: 'public');
          }
        }
      });
    } catch (_) {}
  }

  String _deriveRoleFromEmail(String email) {
    final lower = email.toLowerCase();
    if (lower.contains('admin')) return 'admin';
    if (lower.contains('scorer')) return 'scorer';
    return 'scorer'; // Authenticated users logging in via portal default to scorer
  }

  void setRole(String role) {
    state = state.copyWith(role: role);
  }

  void setDemoUser({required String email, required String role}) {
    state = AppUser(
      uid: 'demo_${role}_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      role: role,
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled the sign-in

      final googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final uid = userCredential.user!.uid;
      final userEmail = userCredential.user!.email ?? googleUser.email;

      try {
        final doc = await FirebaseFirestore.instance
            .doc(FirestorePaths.user(uid))
            .get();
        if (doc.exists && doc.data() != null) {
          state = AppUser.fromMap(uid, doc.data());
        } else {
          final role = _deriveRoleFromEmail(userEmail);
          final user = AppUser(uid: uid, email: userEmail, role: role);
          state = user;
          await FirebaseFirestore.instance
              .doc(FirestorePaths.user(uid))
              .set(user.toMap(), SetOptions(merge: true));
        }
      } catch (_) {
        final role = _deriveRoleFromEmail(userEmail);
        state = AppUser(uid: uid, email: userEmail, role: role);
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      // Fallback for demo/offline
      setDemoUser(email: 'google_scorer@wasacricket.com', role: 'scorer');
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      final userEmail = cred.user!.email ?? email;

      try {
        final doc = await FirebaseFirestore.instance
            .doc(FirestorePaths.user(uid))
            .get();
        if (doc.exists && doc.data() != null) {
          state = AppUser.fromMap(uid, doc.data());
        } else {
          final role = _deriveRoleFromEmail(userEmail);
          final user = AppUser(uid: uid, email: userEmail, role: role);
          state = user;
          await FirebaseFirestore.instance
              .doc(FirestorePaths.user(uid))
              .set(user.toMap(), SetOptions(merge: true));
        }
      } catch (_) {
        final role = _deriveRoleFromEmail(userEmail);
        state = AppUser(uid: uid, email: userEmail, role: role);
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      // Fallback for offline mode
      final role = _deriveRoleFromEmail(email);
      setDemoUser(email: email, role: role);
    }
  }

  Future<void> signUpWithEmail(String email, String password, {String role = 'scorer'}) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      final userEmail = cred.user!.email ?? email;
      final appUser = AppUser(uid: uid, email: userEmail, role: role);

      try {
        await FirebaseFirestore.instance
            .doc(FirestorePaths.user(uid))
            .set(appUser.toMap(), SetOptions(merge: true));
      } catch (_) {}

      state = appUser;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      setDemoUser(email: email, role: role);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    state = const AppUser(uid: 'guest', email: '', role: 'public');
  }
}
