# LocalSongs 🎵

Un lettore musicale moderno, leggero e reattivo per Android sviluppato in **Flutter**. Progettato per riprodurre la propria libreria musicale offline memorizzata sul dispositivo, senza pubblicità, tracking o connessione internet richiesta.

---

## ✨ Funzionalità

* **Scansione Cartelle Personalizzate:** Scegli liberamente quali cartelle della memoria interna o SD scansionare per trovare i tuoi brani (MP3, FLAC, WAV, AAC, ecc.).
* **Riproduzione in Background & Controlli Notifica:** Integra `audio_service` per una notifica multimediale persistente con controlli di riproduzione completi e sincronizzati anche a schermo spento.
* **Now Playing Screen Dedicata:**
  * Cover album / artwork con fallback dinamico.
  * Barra di avanzamento fluida (*Wavy Seek Bar*).
  * Modalità Shuffle e Loop (Loop One / Loop All).
* **Mini Player Persistente:** Barra inferiore sempre a portata di mano con equalizzatore animato.
* **Organizzazione della Libreria:**
  * Tab **Brani** con ricerca istantanea per titolo e artista.
  * Tab **Playlist** personalizzate.
  * Tab **Preferiti** per accesso rapido ai pezzi migliori.
* **Interfaccia Dark Moderna:** Design curato ispirato ai moderni player musicali (Material 3 Dark).

---

## 🚀 Architettura del Progetto

```
lib/
├── main.dart                  # Entry point, gestione tema e foreground service
├── models/
│   ├── playlist_model.dart    # Modello dati playlist
│   └── song_model.dart        # Modello brano e metadati
├── services/
│   ├── audio_handler.dart     # AudioHandler (just_audio + audio_service)
│   └── storage_service.dart   # Scansione filesystem, permessi e SharedPreferences
└── ui/
    ├── screens/
    │   ├── home_screen.dart           # Dashboard principale a tab (Brani, Playlist, Preferiti)
    │   └── now_playing_screen.dart    # Schermata del brano in riproduzione
    └── widgets/
        ├── animated_equalizer.dart    # Animazione barre equalizzatore
        ├── artwork_widget.dart        # Render cover/artwork
        ├── mini_player.dart           # Player compatto fisso in basso
        ├── song_tile.dart             # Elemento lista traccia
        └── wavy_seek_bar.dart         # Seekbar a onde
```

---

## 🛠️ Prerequisiti & Setup Locale

### Requisiti
* **Flutter SDK**: `>= 3.7.0` (testato su 3.29.0)
* **Dart SDK**: `^3.7.0`
* **Android SDK** con Java JDK 17 o 21

### Installazione
1. Clona il repository:
   ```bash
   git clone https://github.com/BeLorenzo/LocalSongs.git
   cd LocalSongs
   ```
2. Installa le dipendenze:
   ```bash
   flutter pub get
   ```
3. Avvia l'applicazione sul tuo dispositivo o emulatore collegato:
   ```bash
   flutter run
   ```

### Compilazione APK Release manuale
```bash
flutter build apk --release
```
Il file generato si troverà in `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📦 CI/CD & Rilascio Automatico (GitHub Actions)

Il progetto include una pipeline GitHub Actions (`.github/workflows/build-apk.yml`) che automatizza la build dell'APK:
* **Trigger su Tag:** Quando crei un tag (es. `v1.0.0`), la pipeline compila l'APK release e crea automaticamente una nuova **GitHub Release** con l'APK pronto al download.
* **Trigger Manuale:** Puoi lanciare la compilazione in qualsiasi momento dalla scheda *Actions* di GitHub con `workflow_dispatch`.

---

## 📄 Licenza
Distribuito sotto licenza MIT. Consulta il file [LICENSE](LICENSE) per ulteriori dettagli.
