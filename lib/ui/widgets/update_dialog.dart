import 'package:flutter/material.dart';
import '../../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> showIfAvailable(
    BuildContext context, {
    bool force = false,
    bool showToastIfUpToDate = false,
  }) async {
    final update = await UpdateService.checkForUpdate(force: force);
    if (!context.mounted) return;

    if (update != null && update.hasUpdate) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => UpdateDialog(updateInfo: update),
      );
    } else if (showToastIfUpToDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L\'applicazione è già aggiornata all\'ultima versione.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parsing e pulizia note di rilascio da GitHub
    final rawNotes = updateInfo.releaseNotes.trim();
    List<String> noteLines = [];

    if (rawNotes.isNotEmpty) {
      noteLines = rawNotes
          .split('\n')
          .map((l) => l.trim())
          .where((l) =>
              l.isNotEmpty &&
              !l.toLowerCase().contains('full changelog') &&
              !l.toLowerCase().contains("what's changed"))
          .map((l) {
            var clean = l.replaceFirst(RegExp(r'^[-*•#\d.]+\s*'), '').trim();
            clean = clean.replaceFirst(RegExp(r'\s+by\s+@\w+.*$', caseSensitive: false), '').trim();
            clean = clean.replaceFirst(
                RegExp(r'^(feat|fix|docs|style|refactor|perf|test|chore)(\(.*?\))?:\s*',
                    caseSensitive: false),
                '').trim();
            if (clean.isNotEmpty) {
              clean = clean[0].toUpperCase() + clean.substring(1);
            }
            return clean;
          })
          .where((l) => l.length > 3)
          .toList();
    }

    if (noteLines.isEmpty) {
      noteLines = ['Miglioramenti generali delle prestazioni e correzioni di stabilità.'];
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF1DB954).withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF1DB954).withValues(alpha: 0.12),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icona in evidenza
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1DB954), Color(0xFF15883e)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.black,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'NUOVA VERSIONE DISPONIBILE',
                  style: TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Titolo versione
              Text(
                'LocalSongs v${updateInfo.latestVersion}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Versione corrente installata: v${updateInfo.currentVersion}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),

              // Riquadro Novità / Note di rilascio
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Novità dell\'aggiornamento:',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: noteLines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4, right: 8),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: Color(0xFF1DB954),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              noteLines[index],
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Bottone Scarica e Aggiorna
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    'Scarica e Aggiorna',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    final downloadUrl =
                        updateInfo.apkDownloadUrl ?? updateInfo.releaseUrl;
                    UpdateService.openDownload(downloadUrl);
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Bottone Più tardi
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade400,
                ),
                child: const Text('Più tardi', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
