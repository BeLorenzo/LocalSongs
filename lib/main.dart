import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_handler.dart';
import 'services/storage_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Imposta lo stile della barra di stato di sistema su scuro
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inizializza il servizio di archiviazione preferenze/database locale
  final storageService = await StorageService.init();

  // Inizializza il Foreground Audio Service nativo
  final audioHandler = await initAudioService() as MusicAudioHandler;

  runApp(MusicPlayerApp(
    audioHandler: audioHandler,
    storageService: storageService,
  ));
}

class MusicPlayerApp extends StatefulWidget {
  final MusicAudioHandler audioHandler;
  final StorageService storageService;

  const MusicPlayerApp({
    super.key,
    required this.audioHandler,
    required this.storageService,
  });

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  late StreamSubscription<String> _errorSub;

  @override
  void initState() {
    super.initState();
    // Ascolta gli errori audio e mostra SnackBar rossi su qualsiasi schermata
    _errorSub = widget.audioHandler.errorStream.listen((errorMessage) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _errorSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Lettore Musicale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1DB954),
          surface: Color(0xFF121212),
          onPrimary: Colors.black,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: HomeScreen(
        audioHandler: widget.audioHandler,
        storageService: widget.storageService,
      ),
    );
  }
}
