import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthMethod { phone, google }
enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthService extends ChangeNotifier {
  // Firebase instances
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Force account picker to show
    // forceCodeForRefreshToken: true, // This option is not standard for GoogleSignIn.
    // Account picker is usually forced by signing out first.
  );

  // Auth state
  AuthState _authState = AuthState.initial;
  String? _errorMessage;
  AuthMethod? _lastMethod;

  // User info
  String? _phoneNumber;
  bool _isPhoneVerified = false;
  GoogleSignInAccount? _googleAccount;
  User? _currentUser;

  // Verification code
  String? _verificationId;
  int? _resendToken;

  // Getters
  AuthState get authState => _authState;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authState == AuthState.authenticated && _currentUser != null;
  bool get isLoading => _authState == AuthState.loading;
  AuthMethod? get lastMethod => _lastMethod;
  String? get phoneNumber => _phoneNumber;
  bool get isPhoneVerified => _isPhoneVerified;
  GoogleSignInAccount? get googleAccount => _googleAccount;
  User? get currentUser => _currentUser;

  Future<void> initialize() async {
    _authState = AuthState.initial;

    try {
      // Listen to auth state changes
      _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);

      // Check current user
      _currentUser = _firebaseAuth.currentUser;

      if (_currentUser != null) {
        await _loadAuthMethod();
        _authState = AuthState.authenticated;
        print('User already authenticated: ${_currentUser!.uid}');
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      print('Error during initialization: $e');
      _authState = AuthState.unauthenticated;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  void _onAuthStateChanged(User? user) async {
    print('Auth state changed: ${user?.uid}');
    _currentUser = user;

    if (user != null) {
      _authState = AuthState.authenticated;
      await _saveAuthMethod(); // Save method when user is confirmed
    } else {
      // Clear all session-related data on sign out or if user becomes null
      _authState = AuthState.unauthenticated;
      _lastMethod = null;
      _phoneNumber = null;
      _isPhoneVerified = false;
      _googleAccount = null;
      // Optionally clear SharedPreferences related to auth method here if desired
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.remove('authMethod');
      // await prefs.remove('phoneNumber');
    }

    notifyListeners();
  }

  Future<void> _loadAuthMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authMethodString = prefs.getString('authMethod');

      if (authMethodString == 'google') {
        _lastMethod = AuthMethod.google;
        // Attempt to re-initialize GoogleSignIn if a user was previously signed in
        // This helps in keeping _googleSignIn.currentUser updated if app was closed.
        if (_firebaseAuth.currentUser != null && _firebaseAuth.currentUser!.providerData.any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID)) {
          _googleAccount = await _googleSignIn.signInSilently();
        }
      } else if (authMethodString == 'phone') {
        _lastMethod = AuthMethod.phone;
        _phoneNumber = prefs.getString('phoneNumber');
        _isPhoneVerified = true; // Assume verified if loaded
      }
    } catch (e) {
      print('Error loading auth method: $e');
    }
  }

  Future<void> _saveAuthMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_lastMethod == AuthMethod.google) {
        await prefs.setString('authMethod', 'google');
        await prefs.remove('phoneNumber'); // Clear phone if switched to Google
      } else if (_lastMethod == AuthMethod.phone) {
        await prefs.setString('authMethod', 'phone');
        if (_phoneNumber != null) {
          await prefs.setString('phoneNumber', _phoneNumber!);
        }
      }
    } catch (e) {
      print('Error saving auth method: $e');
    }
  }

  // Method to clear Google Sign-In cache and force account picker
  Future<void> _clearGoogleSignInCache() async {
    try {
      // Signing out from GoogleSignIn is usually enough to ensure the account picker is shown next time.
      // Disconnect is a more drastic step and revokes permissions.
      await _googleSignIn.signOut();
      // await _googleSignIn.disconnect(); // Use disconnect sparingly, as it revokes token.
      print('Signed out from GoogleSignIn to force account picker.');
    } catch (e) {
      print('Error clearing Google cache: $e');
      // Continue anyway
    }
  }

  // Enhanced Google Sign In with proper UI flow
  Future<bool> signInWithGoogle() async {
    print('=== Starting Google Sign-In ===');

    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Always clear previous Google session to force account picker
      await _clearGoogleSignInCache();

      // Add a small delay to ensure clean state if needed, though usually not necessary after signOut.
      // await Future.delayed(const Duration(milliseconds: 100));

      print('Initiating Google Sign-In flow with account picker...');

      // This should show the Google account selection screen
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('User cancelled Google Sign-In or no account selected.');
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }

      print('Google user selected: ${googleUser.email}');
      print('Display name: ${googleUser.displayName}');

      // Get authentication details
      print('Getting authentication details...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Failed to obtain Google authentication tokens.');
        throw Exception('Failed to obtain Google authentication tokens');
      }

      print('Successfully obtained Google auth tokens.');

      // Create Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Created Firebase credential, signing in...');

      // Sign in to Firebase
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        print('✅ Firebase sign-in successful!');
        print('User ID: ${userCredential.user!.uid}');
        print('Email: ${userCredential.user!.email}');
        print('Display name: ${userCredential.user!.displayName}');

        _googleAccount = googleUser;
        _lastMethod = AuthMethod.google;
        _currentUser = userCredential.user; // _onAuthStateChanged will also set this
        _authState = AuthState.authenticated; // _onAuthStateChanged will also set this

        await _saveAuthMethod(); // Save method after successful Firebase sign-in
        notifyListeners();

        return true;
      } else {
        print('Firebase authentication returned null user.');
        throw Exception('Firebase authentication returned null user');
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      _authState = AuthState.error;
      _errorMessage = _getFirebaseAuthErrorMessage(e); // This line should now work
      _lastMethod = null; // Reset last method on error
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      _authState = AuthState.error;
      _errorMessage = 'Google Sign-in failed. Please check your internet connection and try again.';
      _lastMethod = null; // Reset last method on error
      notifyListeners();
      return false;
    }
  }

  // Simplified Phone verification
  Future<bool> verifyPhoneNumber(String phoneNumber) async {
    print('=== Starting Phone Verification ===');
    print('Phone number: $phoneNumber');

    _authState = AuthState.loading;
    // _lastMethod = AuthMethod.phone; // Set this only on successful initiation or completion
    _errorMessage = null;
    _phoneNumber = phoneNumber; // Store temporarily
    notifyListeners();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('✅ Auto verification completed for $phoneNumber');
          try {
            await _firebaseAuth.signInWithCredential(credential);
            // _onAuthStateChanged will handle setting user, authState, and saving method.
            _isPhoneVerified = true; // Mark as verified
            _lastMethod = AuthMethod.phone; // Confirm method
            // No need to directly set _authState or _currentUser here, _onAuthStateChanged handles it.
            await _saveAuthMethod(); // Ensure phone number is saved if auto-verified
            notifyListeners(); // Notify for UI update if needed before _onAuthStateChanged
          } catch (e) {
            print('❌ Auto-verification sign-in failed: $e');
            _authState = AuthState.error;
            if (e is FirebaseAuthException) {
              _errorMessage = _getFirebaseAuthErrorMessage(e);
            } else {
              _errorMessage = 'Auto-verification sign-in failed.';
            }
            notifyListeners();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Phone verification failed for $phoneNumber: ${e.code} - ${e.message}');
          _authState = AuthState.error;
          _errorMessage = _getFirebaseAuthErrorMessage(e);
          // _errorMessage = 'Phone verification failed. Use test number: +91 7718556613';
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          print('✅ SMS code sent successfully to $phoneNumber. Verification ID: $verificationId');
          _verificationId = verificationId;
          _resendToken = resendToken;
          _authState = AuthState.unauthenticated; // Waiting for code
          _errorMessage = null;
          _lastMethod = AuthMethod.phone; // Method initiated
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Code auto-retrieval timeout for $phoneNumber. Verification ID: $verificationId');
          // You might want to inform the user or handle this case, e.g., by enabling resend.
          _verificationId = verificationId; // Update verificationId if it changes
        },
      );
      return true; // Indicates that the process was initiated
    } catch (e) {
      print('❌ Phone verification error: $e');
      _authState = AuthState.error;
      _errorMessage = 'An unexpected error occurred during phone verification.';
      notifyListeners();
      return false;
    }
  }

  // SMS code verification
  Future<bool> verifySmsCode(String smsCode) async {
    print('=== Verifying SMS Code ===');
    print('Code: $smsCode');

    if (_verificationId == null) {
      _errorMessage = "Verification ID not found. Please request a new code.";
      _authState = AuthState.error;
      notifyListeners();
      return false;
    }

    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // For testing with a hardcoded code (e.g., 123456)
      // This part should ideally be for actual Firebase verification.
      // The previous version had a hardcoded check. Reverting to actual Firebase check.

      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await _firebaseAuth.signInWithCredential(credential);
      // _onAuthStateChanged will handle setting user, authState.
      _isPhoneVerified = true;
      _lastMethod = AuthMethod.phone; // Confirm method
      await _saveAuthMethod(); // Save method and phone number

      print('✅ SMS Code verification successful.');
      notifyListeners(); // Notify for UI update if needed before _onAuthStateChanged
      return true;

    } on FirebaseAuthException catch (e) {
      print('❌ SMS verification failed: ${e.code} - ${e.message}');
      _authState = AuthState.error;
      _errorMessage = _getFirebaseAuthErrorMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Unexpected error during SMS verification: $e');
      _authState = AuthState.error;
      _errorMessage = 'An unexpected error occurred during SMS code verification.';
      notifyListeners();
      return false;
    }
  }


  // Enhanced sign out
  Future<void> signOut() async {
    print('=== Signing Out ===');
    _authState = AuthState.loading;
    notifyListeners();

    try {
      // Sign out from Firebase first
      await _firebaseAuth.signOut();

      // Then sign out from Google if the last method was Google or if a Google account is active
      if (_lastMethod == AuthMethod.google || _googleSignIn.currentUser != null) {
        try {
          await _googleSignIn.signOut();
          print('Signed out from GoogleSignIn.');
          // await _googleSignIn.disconnect(); // Disconnect is more severe, usually not needed for simple sign-out
        } catch (e) {
          print('Google sign out error: $e (Continuing with Firebase sign out)');
        }
      }

      // Clear saved auth state from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authMethod');
      await prefs.remove('phoneNumber');
      // Potentially clear other related keys if you add them

      // Reset internal state variables - _onAuthStateChanged(null) will also do much of this.
      // _isPhoneVerified = false; // Redundant, _onAuthStateChanged handles
      // _googleAccount = null; // Redundant
      // _currentUser = null; // Redundant
      _verificationId = null;
      _resendToken = null;
      _errorMessage = null;
      // _lastMethod and _phoneNumber are cleared by _onAuthStateChanged

      print('✅ Sign out successful. State reset.');
      // _onAuthStateChanged(null) will be triggered by _firebaseAuth.signOut(),
      // which will call notifyListeners(). Calling it here might be redundant
      // but ensures UI updates if _onAuthStateChanged is delayed or doesn't fire as expected.
      notifyListeners();
    } catch (e) {
      print('❌ Sign out error: $e');
      _errorMessage = 'Sign out failed. Please try again.';
      _authState = AuthState.unauthenticated; // Ensure state reflects failure
      notifyListeners();
    }
  }

  // Reset error state
  void resetError() {
    _errorMessage = null;
    if (_authState == AuthState.error) {
      // Revert to a sensible default state, usually unauthenticated
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // Helper method to convert FirebaseAuthException to a user-friendly message
  String _getFirebaseAuthErrorMessage(FirebaseAuthException error) {
    print("Firebase Auth Error Code: ${error.code}");
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'invalid-credential':
        return 'The credential provided is invalid or has expired. Please try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up or try a different email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-verification-code':
        return 'The verification code is invalid. Please enter the correct code.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid. This might happen if the session expired.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many requests. Please wait a moment and try again.';
      case 'app-not-authorized':
        return 'This app is not authorized to use Firebase Authentication with the provided API key.';
      case 'invalid-phone-number':
        return 'The phone number is not valid. Please check the format.';
      case 'missing-phone-number':
        return 'Phone number is missing. Please provide a phone number.';
      case 'quota-exceeded':
        return 'SMS verification quota exceeded. Please try the test number or contact support.';
      case 'cancelled': // For phone auth, if user cancels (e.g. closes reCAPTCHA)
        return 'Phone verification was cancelled.';
      case 'session-expired':
        return 'The SMS code has expired. Please request a new one.';
    // Add more specific cases as needed based on Firebase documentation
      default:
        return 'An unexpected authentication error occurred. Please try again. (Code: ${error.code})';
    }
  }
}
