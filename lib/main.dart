// This file contains the complete, single-file Flutter Web application for the Wedding Shower Guest Wish App.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guest_wish_app/Utils/brandColor.dart';
import 'package:guest_wish_app/language.dart';
import 'dart:async'; // Required for TimeoutException

// NOTE: In a real Flutter project, the 'firebase_options.dart' file is generated
// by the 'flutterfire configure' command and contains your specific keys.
// For this environment, we rely on the platform to link the config.
import 'firebase_options.dart'; 

// -----------------------------------------------------------------------------
// 1. ENVIRONMENT/GLOBAL VARIABLES & COLORS
// -----------------------------------------------------------------------------
const String __app_id = 'flutter-wedding-wishes-12345';
const String __initial_auth_token = ''; 



// --- CRITICAL ADMIN CONFIGURATION ---
// IMPORTANT: Replace these with the actual UIDs of Lydia and Fisha from your Firebase project.
final List<String> ADMIN_UIDS = const [
  'jvMcF5KnmTUvzwYB4tFpTwM0kuE2', // Placeholder for Lydia's actual UID
  'UZ7b5twgf4bkBVqP3tllVQqMeUI3', // Placeholder for Fisha's actual UID
];
// ------------------------------------

// -----------------------------------------------------------------------------
// 2. LOCALIZATION SETUP (NEW)
// -----------------------------------------------------------------------------
enum AppLocale { en, am }

class AppLocalizations {
  // Mapping of translation keys to localized strings
  static final Map<String, Map<AppLocale, String>> _localizedValues = {
    // UI TEXT
    'wishesGuestbookTitle': {
      AppLocale.en: 'Wishes Guestbook',
      AppLocale.am: 'የምኞት መዝገብ', // Ye'mignot Mezgib
    },
    'leaveBestWishes': {
      AppLocale.en: 'Leave Your best wishes or any messages',
      AppLocale.am: 'መልካም ምኞቶን ወይም ምርቃትዎን ይተዉ', // Mirt Mignotwon Weyim Mele'ktwon Yetewu
    },
    'statusAdminView': {
      AppLocale.en: 'Status: Admin View',
      AppLocale.am: 'ሁኔታ: አስተዳዳሪ እይታ', // Huneta: Asetedadari I'yeta
    },
    'statusGuestView': {
      AppLocale.en: 'Status: Guest View',
      AppLocale.am: 'ሁኔታ: እንግዳ እይታ', // Huneta: Ingida I'yeta
    },
    'userId': {
      AppLocale.en: 'User ID',
      AppLocale.am: 'የተጠቃሚ መለያ', // Yeteteqami Meleya
    },
    'shareYourLove': {
      AppLocale.en: 'Share Your Love',
      AppLocale.am: 'ፍቅርዎን ያካፍሉ', // Fikirwon Yakafilu
    },
    'yourNameHint': {
      AppLocale.en: 'Your Name (e.g., Aunt Samri)',
      AppLocale.am: 'ስምዎ (ለምሳሌ: አክስት ሳምሪ)', // Simwo (lamesale: Akist Samri)
    },
    'writeYourWishHint': {
      AppLocale.en: 'Write your heartfelt wish or advice here...',
      AppLocale.am: 'ከልብ የመነጨ ምኞትዎን ወይም ምክርዎን ይጻፉ...', // Kalib Yemeneche Mignotwon Weyim Mikirwon Yitsafu...
    },
    'chooseReaction': {
      AppLocale.en: 'Choose a reaction:',
      AppLocale.am: 'ስሜት ይምረጡ:', // Semet Yimretu:
    },
    'sending': {
      AppLocale.en: 'Sending...',
      AppLocale.am: 'በመላክ ላይ...', // Bemelak Lay...
    },
    'submitWish': {
      AppLocale.en: 'Submit Wish',
      AppLocale.am: 'ምኞት ያስገቡ', // Mignot Yasgebbu
    },
    'wishesFromLovedOnes': {
      AppLocale.en: 'Wishes from Our Loved Ones',
      AppLocale.am: 'ከምንወዳቸው ሰዎች የተላኩ ምኞቶች', // Keminwodachew Sewoch Yetelaku Mignotoch
    },
    'loadingWishes': {
      AppLocale.en: 'Loading wishes...',
      AppLocale.am: 'ምኞቶች እየተጫኑ ነው...', // Mignotoch Iyetechanu New...
    },
    'beTheFirst': {
      AppLocale.en: 'Be the first to leave a wish!',
      AppLocale.am: 'የመጀመሪያው ምኞትዎን ይተዉ!', // Yemajameriya Mignotwon Yetewu!
    },
    
    // ERROR / MODAL TEXT
    'enterBothFieldsError': {
      AppLocale.en: "Please enter both your name and a message.",
      AppLocale.am: "እባክዎ ስምዎን እና መልእክትዎን ያስገቡ።", // Ibakwo Simwon ina Mele'ktwon Yasgebbu.
    },
    'submissionTimeout': {
      AppLocale.en: 'Submission timed out (15s). Please check your connection and try again.',
      AppLocale.am: 'ማስረከብ ጊዜው አልቋል። እባክዎ ግንኙነትዎን ያረጋግጡ።', // Masrekeb Gizew Alqua. Ibakwo Gininyetwon Yaregagit.
    },
    'connectionError': {
      AppLocale.en: 'Connection error: The service is currently unreachable. Please try again.',
      AppLocale.am: 'የግንኙነት ስህተት: አገልግሎቱ በአሁኑ ጊዜ አይገኝም። እንደገና ይሞክሩ።', // Yegininyet Sihtet: Agelgilotu Bahunu Gize Ayginm. Andegena Yimokiru.
    },
    'unexpectedError': {
      AppLocale.en: 'An unexpected error occurred. Please try again.',
      AppLocale.am: 'ያልተጠበቀ ስህተት ተከስቷል። እንደገና ይሞክሩ።', // Yaltetebbeke Sihtet Tekestwa. Andegena Yimokiru.
    },
    'wishSentTitle': {
      AppLocale.en: 'Wish Sent!',
      AppLocale.am: 'ምኞት ተልኳል!', // Mignot Telkual!
    },
    'wishSentMessage': {
      AppLocale.en: 'Done! Your wish has been successfully added to our memories.',
      AppLocale.am: 'ተጠናቋል! ምኞትዎ በተሳካ ሁኔታ ወደ ትዝታዎቻችን ታክሏል።', // Tetenaqwal! Mignotwo Betesakka Huneta Wede Tizitawochachin Taklual.
    },
    'close': {
      AppLocale.en: 'CLOSE',
      AppLocale.am: 'ዝጋ', // Ziga
    },

    // ADMIN VIEW RESTRICTED
    'viewRestrictedTitle': {
      AppLocale.en: 'Wishes View Restricted',
      AppLocale.am: 'ምኞቶችን ማየት የተከለከለ ነው', // Mignotochin Mayet Yetekelkale New
    },
    'viewRestrictedMessage': {
      AppLocale.en: 'Thank you for submitting your message! Only the hosts (Lydia and Fisha) can view the collection of wishes.',
      AppLocale.am: 'መልእክትዎን ስላስገቡ እናመሰግናለን! ምኞቶቹን ማየት የሚችሉት አስተናጋጆቹ (ሊዲያ እና ፊሻ) ብቻ ናቸው።', // Mele'ktwon Sliasgebbu Nameseginalen! Mignotochun Mayet Yemichilut Astena-gochu (Lidiya ina Fisha) Bicha Nachu.
    },
    
    // LOGIN MODAL
    'adminLogin': {
      AppLocale.en: 'Admin Login',
      AppLocale.am: 'የአድሚን መግቢያ', // Asetedadari Megbiya
    },
    'adminLogout': {
      AppLocale.en: 'Admin Logout',
      AppLocale.am: 'አስተዳዳሪ ውጣ', // Asetedadari Weta
    },
    'loginFailed': {
      AppLocale.en: 'Login Failed. Check email/password.',
      AppLocale.am: 'መግባት አልተሳካም። ኢሜል/የይለፍ ቃል ያረጋግጡ።', // Megbat Altesaka. Email/Yilef Qal Yaregagit.
    },
    'invalidCredentials': {
      AppLocale.en: 'Invalid credentials. Please try again.',
      AppLocale.am: 'ልክ ያልሆነ መረጃ። እንደገና ይሞክሩ።', // Lik Yalhone Mereja. Andegena Yimokiru.
    },
    'unexpectedLoginError': {
      AppLocale.en: "An unexpected error occurred during login.",
      AppLocale.am: "ያልተጠበቀ የመግቢያ ስህተት ተከስቷል።", // Yaltetebbeke Yemegbiya Sihtet Tekestwa.
    },
    'loginWelcome': {
      AppLocale.en: "Welcome back, Admin!",
      AppLocale.am: "እንኳን ደህና መጡ፣ አስተዳዳሪ!", // Inkuan Dehna Metu, Asetedadari!
    },
    'logoutSuccess': {
      AppLocale.en: "Signed out. Switched to Guest mode.",
      AppLocale.am: "ወጥተዋል። ወደ እንግዳ ሁነታ ተቀይሯል።", // Wetewal. Wede Ingida Huneta Tekeyrual.
    },
    'logoutFailed': {
      AppLocale.en: "Logout failed.",
      AppLocale.am: "መውጣት አልተሳካም።", // Mewetat Altesaka.
    },
    'emailHint': {
      AppLocale.en: 'Email',
      AppLocale.am: 'ኢሜል', // Email (Lidiya Weyim Fisha)
    },
    'passwordHint': {
      AppLocale.en: 'Password',
      AppLocale.am: 'የይለፍ ቃል', // Yilef Qal
    },
    'enterEmailPassword': {
      AppLocale.en: "Please enter both email and password.",
      AppLocale.am: "እባክዎ ኢሜል እና የይለፍ ቃል ያስገቡ።", // Ibakwo Email ina Yilef Qal Yasgebbu.
    },
    'signInButton': {
      AppLocale.en: 'Sign In',
      AppLocale.am: 'ይግቡ', // Yigbu
    },
  };

  static String of(String key, AppLocale locale) {
    return _localizedValues[key]?[locale] ?? key;
  }
}

// -----------------------------------------------------------------------------
// 3. MAIN FUNCTION AND APP WIDGET
// -----------------------------------------------------------------------------
void main() async {
  // Ensure Flutter is initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the options generated by FlutterFire CLI
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  //  runApp(MaterialApp(
  //     title: AppLocalizations.of('wishesGuestbookTitle', AppLocale.en),
  //   debugShowCheckedModeBanner: false,
  //   home: SelectLocation(),
  // ));
    runApp(Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400), // phone width
                child:  const WishApp())));
}

class WishApp extends StatelessWidget {
  //  final String language;

 
  const WishApp({super.key,
  // required  this.language
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       debugShowCheckedModeBanner: false,
      title: AppLocalizations.of('wishesGuestbookTitle', 
      // language=='English'?
      AppLocale.en
      // :AppLocale.am
      ), // Default title language
      // Using Inter and Playfair Display for an elegant look
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: backgroundColor, // Soft Pink Background
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home:  WishHomePage(
        // language: language
        ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. HOME PAGE STATEFUL WIDGET
// -----------------------------------------------------------------------------
class WishHomePage extends StatefulWidget {
    // final String language;

 
  const WishHomePage({super.key,
  // required this.language
  });

  @override
  State<WishHomePage> createState() => _WishHomePageState();
}

class _WishHomePageState extends State<WishHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  // --- LANGUAGE STATE ---
  AppLocale _currentLocale = AppLocale.am; 

  String _userId = 'anonymous';
  bool _isLoading = true;
  String? _error; // Error message state
  bool _showLoginModal = false; // State for modal visibility

  String _selectedEmoji = '💖'; // Default emoji
  final List<String> _emojiOptions = ['💖', '😊', '😂','🥹', '😲','🎉', '🥂', ];
  
  bool get _isAdmin => ADMIN_UIDS.contains(_auth.currentUser?.uid);

  // Helper function to get localized string
  String getLocalized(String key) => AppLocalizations.of(key, _currentLocale);

  late final CollectionReference _wishesRef;

  @override
  void initState() {
    super.initState();
    _currentLocale =
    //  widget.language=='English'?
     AppLocale.en
    //  :AppLocale.am
     ; 
    
    _wishesRef = _db.collection('artifacts/${__app_id}/public/data/weddingWishes');
    _initializeAuthAndLoad();

    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _userId = user?.uid ?? 'unknown';
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeAuthAndLoad() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (_auth.currentUser == null) {
        if (__initial_auth_token.isNotEmpty) {
          await _auth.signInWithCustomToken(__initial_auth_token);
        } else {
          await _auth.signInAnonymously();
        }
      }
      _userId = _auth.currentUser?.uid ?? 'unknown';
    } on FirebaseException catch (e) {
      _error = 'Firebase Auth Error: ${e.message}';
      print('Auth Error: $_error');
    } catch (e) {
      _error = getLocalized('unexpectedError');
      print('Init Error: $_error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // --- Admin Login/Logout Logic ---
  Future<void> _adminSignIn(String email, String password) async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _showSuccessToast(context, getLocalized('loginWelcome'));
      setState(() => _showLoginModal = false); 
    } on FirebaseAuthException catch (e) {
      String msg = getLocalized('loginFailed');
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = getLocalized('invalidCredentials');
      }
      _showErrorToast(context, msg);
    } catch (e) {
      _showErrorToast(context, getLocalized('unexpectedLoginError'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _adminSignOut() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signOut();
      _showSuccessToast(context, getLocalized('logoutSuccess'));
      await _auth.signInAnonymously(); 
    } catch (e) {
      _showErrorToast(context, getLocalized('logoutFailed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // -------------------------------------


  Future<void> _addWish() async {
    final name = _nameController.text.trim();
    final message = _messageController.text.trim();

    if (name.isEmpty || message.isEmpty) {
      setState(() {
        _error = "እባክዎ ስምዎን እና መልእክትዎን ያስገቡ።\nPlease enter both your name and a message.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _wishesRef.add({
        'name': name,
        'message': message,
        'emoji': _selectedEmoji,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _userId,
      }).timeout(const Duration(seconds: 15)); 

      _nameController.clear();
      _messageController.clear();
      
      if (mounted) {
        _showConfirmationDialog(context);
      }
      
    } on TimeoutException {
      setState(() {
        _error = getLocalized('submissionTimeout');
      });
    } on FirebaseException catch (e) {
      String userMessage;
      if (e.code == 'unavailable' || e.code == 'transport-security-error' || e.code == 'network-request-failed') {
        userMessage = getLocalized('connectionError');
      } else {
        userMessage = 'Failed to submit wish: ${e.message}';
      }

      setState(() {
        _error = userMessage;
      });
      print('Firestore Error: $e'); 
    } catch (e) {
      setState(() {
        _error = getLocalized('unexpectedError');
      });
      print('General Submission Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showToast(BuildContext context, String message, {Color color = Colors.green}) {
    final snackBar = SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  void _showSuccessToast(BuildContext context, String message) => _showToast(context, message, color: Colors.green.shade600);
  void _showErrorToast(BuildContext context, String message) => _showToast(context, message, color: primaryColor);

  // ---------------------------------------------------------------------------
  // 5. UI COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // English Selector
          GestureDetector(
            onTap: () => setState(() => _currentLocale = AppLocale.en),
            child: Text(
              'EN',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _currentLocale == AppLocale.en ? primaryColor : Colors.grey.shade500,
                decoration: _currentLocale == AppLocale.en ? TextDecoration.underline : TextDecoration.none,
                decorationColor: primaryColor,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('|', style: TextStyle(color: Colors.grey)),
          ),
          // Amharic Selector
          GestureDetector(
            onTap: () => setState(() => _currentLocale = AppLocale.am),
            child: Text(
              'አማ', // Amharic abbreviation
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _currentLocale == AppLocale.am ? primaryColor : Colors.grey.shade500,
                decoration: _currentLocale == AppLocale.am ? TextDecoration.underline : TextDecoration.none,
                decorationColor: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading && _auth.currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              Text('Signing in and loading...', style: TextStyle(color: primaryColor)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'የምኞት መዝገብ\nWishes Guestbook',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: primaryColor,
            fontSize: 20
          ),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 4,
        actions: [
          // Admin Login/Logout Button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isAdmin
                ? Tooltip(
                    message: getLocalized('adminLogout'),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: primaryColor),
                      onPressed: _adminSignOut,
                    ),
                  )
                : Tooltip(
                    message: getLocalized('adminLogin'),
                    child: IconButton(
                      icon: const Icon(Icons.login, color: primaryColor),
                      onPressed: () {
                        setState(() {
                          _showLoginModal = true;
                        });
                      },
                    ),
                  ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Header Details & Language Selector
                     if(!_isAdmin )
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.shade50.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // _buildLanguageSelector(), // NEW LANGUAGE SWITCHER
                          const SizedBox(height: 12),
                          Text(
                            'መልካም ምኞቶን ወይም ምርቃትዎን ይተዉ\nLeave Your best wishes or any messages',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if(_isAdmin)
                           Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_isAdmin ? Icons.person : Icons.lock_outline, size: 16, color: _isAdmin ? Colors.green : Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  _isAdmin ? getLocalized('statusAdminView') : getLocalized('statusGuestView'),
                                  style: TextStyle(fontSize: 12, color: _isAdmin ? Colors.green.shade700 : Colors.grey.shade600, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),

                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Wish Submission Form
                    if(!_isAdmin )
                    _buildWishForm(),
                     if(!_isAdmin )
                    const SizedBox(height: 32),

                    // Wishes Display Area (Conditional)
                    if(_isAdmin)
                     Text(
                                 getLocalized('statusAdminView') ,
                                  style: TextStyle(fontSize: 12, color: _isAdmin ? Colors.green.shade700 : Colors.grey.shade600, fontWeight: FontWeight.bold),
                                ),
                                if(_isAdmin)
                    _buildWishList(),
                  ],
                ),
              ),
            ),
          ),
          // Admin Login Modal Overlay: Shows when _showLoginModal is true
          if (_showLoginModal) 
            AdminLoginModal(
              onClose: () => setState(() => _showLoginModal = false),
              onLogin: _adminSignIn,
              isLoading: _isLoading,
              locale: _currentLocale, // Pass locale
            ),
        ],
      ),
    );
  }

  // UPDATED: All static strings are now localized.
  Widget _buildWishForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, backgroundColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: backgroundColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              Icon(Icons.favorite, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'ፍቅርዎን ያካፍሉ. Share Your Love',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name Input
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'ስምዎ/ Your Name (e.g., Aunt Samri)',
              hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.black87
                ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          // Message Input
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'ከልብ የመነጨ ምኞትዎን ወይም ምክርዎን ይጻፉ...\nWrite your heartfelt wish or advice here...',
              hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.black87
                ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
            Text(
           'ስሜት ይምረጡ:\nChoose a reaction:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _emojiOptions.map((emoji) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedEmoji = emoji;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _selectedEmoji == emoji ? borderColor.withOpacity(0.3) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedEmoji == emoji ? primaryColor : borderColor.withOpacity(0.5),
                      width: _selectedEmoji == emoji ? 2 : 1,
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 20),
          // Submit Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _addWish,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : null,
              label: Text(_isLoading ? getLocalized('sending') : 'ምኞት ያስገቡ\nSubmit Wish',
              style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                elevation: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishList() {
    if (!_isAdmin) {
      return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
            ],
            border: Border.all(color: Colors.pink.shade100),
          ),
          child: Column(
            children: [
              Icon(Icons.lock_outline, size: 48, color: Colors.pink.shade400),
              const SizedBox(height: 12),
              Text(
                getLocalized('viewRestrictedTitle'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                getLocalized('viewRestrictedMessage'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              ),
            ],
          ),
      );
    }

    // Admin View: Show the list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          getLocalized('wishesFromLovedOnes'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const Divider(color: primaryColor),
        const SizedBox(height: 16),

        StreamBuilder<QuerySnapshot>(
          stream: _wishesRef.orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: borderColor),
                      const SizedBox(height: 8),
                      Text(getLocalized('loadingWishes')),
                    ],
                  )
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading wishes: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.pink.shade100),
                  ),
                  child: Text(
                    getLocalized('beTheFirst'),
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                  ),
                ),
              );
            }

            final wishes = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: wishes.length,
              itemBuilder: (context, index) {
                final data = wishes[index].data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0), // Spacing between dynamically sized cards
                  child: WishCard(
                    name: data['name'] ?? 'Anonymous',
                    message: data['message'] ?? 'No message.',
                    timestamp: data['timestamp'],
                    emoji: data['emoji'] ?? '🤍',
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
  
  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: backgroundColor,
          title: Text(
           'ምኞት ተልኳል!\nWish Sent!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: primaryColor, 
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.favorite_outline,
                color: primaryColor,
                size: 40.0,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                 'ተጠናቋል! ምኞትዎ በተሳካ ሁኔታ ወደ ማስታወሻችን ታክሏል።\nDone! Your wish has been successfully added to our memories.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
               'ዝጋ / close',
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// 6. WISH CARD WIDGET
// -----------------------------------------------------------------------------
class WishCard extends StatelessWidget {
  final String name;
  final String message;
  final Timestamp? timestamp;
  final String emoji;

  const WishCard({
    super.key,
    required this.name,
    required this.message,
    this.timestamp,
    this.emoji = '🤍', 
  });

  @override
  Widget build(BuildContext context) {
    String formattedTime = 'Moment Ago';
    if (timestamp != null) {
      DateTime date = timestamp!.toDate();
      formattedTime = '${date.month}/${date.day}/${date.year}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: borderColor, width: 4)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // The card content can now grow in height based on the text
        children: <Widget>[
          // --- CHANGE: Message text now allows full expansion ---
          Text(
            '"$message"',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade700,
            ),
          ),
          // --- END CHANGE ---
          
          const Divider(height: 16, thickness: 1, color: Colors.grey),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: [
                  Text(
                    emoji, 
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              Text(
                formattedTime,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// 7. ADMIN LOGIN MODAL WIDGET
// -----------------------------------------------------------------------------
class AdminLoginModal extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String, String) onLogin;
  final bool isLoading;
  final AppLocale locale; // Pass locale to modal

  const AdminLoginModal({
    super.key,
    required this.onClose,
    required this.onLogin,
    required this.isLoading,
    required this.locale,
  });

  @override
  State<AdminLoginModal> createState() => _AdminLoginModalState();
}

class _AdminLoginModalState extends State<AdminLoginModal> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _localError;
  
  String getLocalized(String key) => AppLocalizations.of(key, widget.locale);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    _localError = null;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _localError = getLocalized('enterEmailPassword');
      });
      return;
    }

    widget.onLogin(email, password);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54, 
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      getLocalized('adminLogin'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: getLocalized('emailHint'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.email, color: borderColor),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: getLocalized('passwordHint'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.lock, color: borderColor),
                  ),
                ),
                
                if (_localError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _localError!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                  
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 5,
                    ),
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(getLocalized('signInButton'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
