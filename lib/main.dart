import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_handler.dart';
import 'services/settings_service.dart';
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

  // Inizializza il servizio impostazioni & personalizzazione
  final settingsService = await SettingsService.init();

  // Inizializza il Foreground Audio Service nativo
  final audioHandler = await initAudioService() as MusicAudioHandler;

  runApp(MusicPlayerApp(
    audioHandler: audioHandler,
    storageService: storageService,
    settingsService: settingsService,
  ));
}

class MusicPlayerApp extends StatefulWidget {
  final MusicAudioHandler audioHandler;
  final StorageService storageService;
  final SettingsService settingsService;

  const MusicPlayerApp({
    super.key,
    required this.audioHandler,
    required this.storageService,
    required this.settingsService,
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
    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        final settings = widget.settingsService;
        final accent = settings.accentColor;
        final bg = settings.backgroundColor;
        final surface = settings.surfaceColor;

        return MaterialApp(
          scaffoldMessengerKey: _scaffoldMessengerKey,
          title: 'LocalSongs',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: bg,
            colorScheme: ColorScheme.dark(
              primary: accent,
              surface: surface,
              onPrimary: Colors.black,
              onSurface: Colors.white,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: bg,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          home: HomeScreen(
            audioHandler: widget.audioHandler,
            storageService: widget.storageService,
            settingsService: widget.settingsService,
          ),
        );
      },
    );
  }
}
