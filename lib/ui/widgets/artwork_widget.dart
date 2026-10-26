import 'package:flutter/material.dart';

class ArtworkWidget extends StatelessWidget {
  final String title;
  final String artist;
  final double size;
  final double borderRadius;
  final bool isLarge;

  const ArtworkWidget({
    super.key,
    required this.title,
    required this.artist,
    this.size = 48,
    this.borderRadius = 8,
    this.isLarge = false,
  });

  static const List<List<Color>> _gradientPalettes = [
    [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)], // Sunset Flame
    [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], // Deep Ocean
    [Color(0xFF134E5E), Color(0xFF71B280)],                     // Emerald Sea
    [Color(0xFF2B5876), Color(0xFF4E4376)],                     // Cosmic Purple
    [Color(0xFF000428), Color(0xFF004E92)],                     // Midnight Blue
    [Color(0xFF1F1C18), Color(0xFF8E0E00)],                     // Dark Crimson
    [Color(0xFF1D2671), Color(0xFFC33764)],                     // Neon Violet
    [Color(0xFF0D1B2A), Color(0xFF415A77)],                     // Slate Night
    [Color(0xFF1E3C72), Color(0xFF2A5298)],                     // Royal Blue
    [Color(0xFF141E30), Color(0xFF243B55)],                     // Dark Chrome
  ];

  @override
  Widget build(BuildContext context) {
    final hash = (title.hashCode ^ artist.hashCode).abs();
    final gradient = _gradientPalettes[hash % _gradientPalettes.length];

    final initial = (artist.isNotEmpty && artist != 'Artista sconosciuto')
        ? artist.substring(0, 1).toUpperCase()
        : (title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '♫');

    return LayoutBuilder(
      builder: (context, constraints) {
        final double effectiveSize = (size.isFinite && size > 0)
            ? size
            : (constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 280.0);

        return Container(
          width: effectiveSize,
          height: effectiveSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: isLarge
                ? [
                    BoxShadow(
                      color: gradient.first.withAlpha(100),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(180),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Effetto cerchi concentrici stile vinile (solo per la cover grande)
              if (isLarge) ...[
                Container(
                  width: effectiveSize * 0.85,
                  height: effectiveSize * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(15), width: 1.5),
                  ),
                ),
                Container(
                  width: effectiveSize * 0.65,
                  height: effectiveSize * 0.65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(15), width: 1.5),
                  ),
                ),
                Container(
                  width: effectiveSize * 0.45,
                  height: effectiveSize * 0.45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(15), width: 1.5),
                  ),
                ),
              ],
              // Iniziale o icona musicale stilizzata
              Center(
                child: isLarge
                    ? Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: effectiveSize * 0.32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: effectiveSize * 0.45,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
