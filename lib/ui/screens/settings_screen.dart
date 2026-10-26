import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/song_model.dart';
import '../../services/audio_handler.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../widgets/update_dialog.dart';
import 'car_mode_screen.dart';

class SettingsScreen extends StatefulWidget {
  final MusicAudioHandler audioHandler;
  final StorageService storageService;
  final SettingsService settingsService;
  final List<SongModel> songs;
  final VoidCallback onLibraryReloadNeeded;

  const SettingsScreen({
    super.key,
    required this.audioHandler,
    required this.storageService,
    required this.settingsService,
    required this.songs,
    required this.onLibraryReloadNeeded,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.2';
  bool _isCleaningCache = false;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {}
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final accentColor = widget.settingsService.accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        final settings = widget.settingsService;
        final accentColor = settings.accentColor;
        final stats = widget.storageService.getLibraryStats(widget.songs);

        return Scaffold(
          backgroundColor: settings.backgroundColor,
          appBar: AppBar(
            backgroundColor: settings.backgroundColor,
            title: const Text(
              'Impostazioni & Info',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          body: ListView(
            children: [
          // --- STATISTICHE LIBRERIA ---
          _buildSectionHeader('Statistiche Libreria', Icons.analytics_outlined),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: settings.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('${stats.totalSongs}', 'Brani', Icons.music_note_rounded),
                  _buildStatItem(stats.formattedSize, 'Spazio Audio', Icons.storage_rounded),
                  _buildStatItem('${stats.totalPlaylists}', 'Playlist', Icons.playlist_play_rounded),
                  _buildStatItem('${stats.totalFolders}', 'Cartelle', Icons.folder_rounded),
                ],
              ),
            ),
          ),

          // --- ASPETTO & TEMA ---
          _buildSectionHeader('Personalizzazione Grafica', Icons.palette_outlined),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: settings.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      'Colore Principale (Accent)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: SettingsService.availableAccentColors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (ctx, idx) {
                        final opt = SettingsService.availableAccentColors[idx];
                        final isSelected = settings.accentColor.toARGB32() == opt.color.toARGB32();
                        return GestureDetector(
                          onTap: () => settings.setAccentColor(opt.color),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: opt.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: opt.color.withAlpha(150),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.black, size: 22)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Nero Assoluto AMOLED', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Sfondo completamente nero (#000000) ideale per schermi OLED',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    value: settings.isAmoledBlack,
                    activeColor: accentColor,
                    onChanged: (val) => settings.setAmoledBlack(val),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  SwitchListTile(
                    title: const Text('Seekbar a Onda Fluida', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Mostra la barra di riproduzione dinamica a onde anziché la linea dritta',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    value: settings.isWavySeekBar,
                    activeColor: accentColor,
                    onChanged: (val) => settings.setWavySeekBar(val),
                  ),
                ],
              ),
            ),
          ),

          // --- AUDIO & RIPRODUZIONE ---
          _buildSectionHeader('Audio & Riproduzione', Icons.tune_rounded),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: settings.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.equalizer_rounded, color: accentColor),
                    title: const Text('Equalizzatore di Sistema', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Apri il pannello effetti audio nativo di Android / Dolby Atmos',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await widget.audioHandler.openSystemEqualizer();
                      if (!ok && mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Nessun equalizzatore nativo trovato su questo dispositivo.'),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: Icon(Icons.speed_rounded, color: accentColor),
                    title: const Text('Velocità di riproduzione', style: TextStyle(color: Colors.white)),
                    trailing: DropdownButton<double>(
                      value: settings.playbackSpeed,
                      dropdownColor: settings.cardColor,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0.75, child: Text('0.75x', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 1.0, child: Text('1.0x (Normale)', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 1.25, child: Text('1.25x', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 1.5, child: Text('1.5x', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 2.0, child: Text('2.0x', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          settings.setPlaybackSpeed(val);
                          widget.audioHandler.setPlaybackSpeed(val);
                        }
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: Icon(Icons.fast_forward_rounded, color: accentColor),
                    title: const Text('Salto avanti/indietro', style: TextStyle(color: Colors.white)),
                    trailing: DropdownButton<int>(
                      value: settings.seekStepSeconds,
                      dropdownColor: settings.cardColor,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5 secondi', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 10, child: Text('10 secondi', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 15, child: Text('15 secondi', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 30, child: Text('30 secondi', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          settings.setSeekStepSeconds(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- LIBRERIA & PULIZIA ---
          _buildSectionHeader('Libreria & Pulizia', Icons.auto_delete_outlined),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: settings.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.filter_alt_outlined, color: accentColor),
                    title: const Text('Filtro audio brevi (WhatsApp/Notifiche)', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Ignora automaticamente file brevissimi, memo vocali e suonerie',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: DropdownButton<int>(
                      value: settings.minDurationSeconds,
                      dropdownColor: settings.cardColor,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Nessun filtro', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 15, child: Text('> 15 secondi', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 30, child: Text('> 30 secondi', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 60, child: Text('> 60 secondi', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await settings.setMinDurationSeconds(val);
                          widget.onLibraryReloadNeeded();
                        }
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  SwitchListTile(
                    secondary: Icon(Icons.cleaning_services_rounded, color: accentColor),
                    title: const Text('Pulisci titoli brani (Clean Titles)', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Rimuove tag come [Official Video], (Lyrics), yt1s.com dai titoli',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    value: settings.cleanTitlesEnabled,
                    activeColor: accentColor,
                    onChanged: (val) => settings.setCleanTitlesEnabled(val),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: Icon(Icons.cached_rounded, color: accentColor),
                    title: const Text('Svuota cache temporanea', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Elimina file temporanei e reimposta cache', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: _isCleaningCache
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(
                            child: const Text('Svuota'),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _isCleaningCache = true);
                              await widget.storageService.clearTemporaryCache();
                              if (mounted) {
                                setState(() => _isCleaningCache = false);
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Cache temporanea svuotata con successo!')),
                                );
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // --- STRUMENTI KILLER ---
          _buildSectionHeader('Strumenti', Icons.handyman_outlined),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: settings.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: Icon(Icons.directions_car_rounded, color: accentColor),
                title: const Text('Modalità Guida (Car Mode)', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Interfaccia a tutto schermo con tasti giganti e gesture rapide per l\'auto',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CarModeScreen(
                        audioHandler: widget.audioHandler,
                        storageService: widget.storageService,
                        settingsService: widget.settingsService,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // --- INFO & AGGIORNAMENTI ---
          _buildSectionHeader('Informazioni & Aggiornamenti', Icons.info_outline_rounded),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: settings.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.system_update_rounded, color: accentColor),
                    title: const Text('Controlla aggiornamenti', style: TextStyle(color: Colors.white)),
                    subtitle: Text('Versione installata: v$_appVersion', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.refresh_rounded, color: Colors.grey),
                    onTap: () {
                      UpdateDialog.showIfAvailable(context, force: true, showToastIfUpToDate: true);
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: Icon(Icons.code_rounded, color: accentColor),
                    title: const Text('Codice Sorgente GitHub', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('github.com/BeLorenzo/LocalSongs', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.open_in_new_rounded, color: Colors.grey, size: 18),
                    onTap: () {
                      launchUrl(
                        Uri.parse('https://github.com/BeLorenzo/LocalSongs'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: Icon(Icons.verified_user_outlined, color: accentColor),
                    title: const Text('Licenza Software', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('MIT License • Open Source & Gratuita', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
      },
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }
}
