# LocalSongs 🎵

Un lettore musicale moderno, leggero e reattivo per Android sviluppato in **Flutter**. Progettato per riprodurre la propria libreria musicale offline memorizzata sul dispositivo, senza pubblicità, tracking o connessione internet richiesta.

---

## ✨ Funzionalità

* **Scansione Cartelle Personalizzate:** Scegli liberamente quali cartelle della memoria interna o SD scansionare per trovare i tuoi brani (MP3, FLAC, WAV, AAC, ecc.).
* **Ordinamento Flessibile dei Brani:**
  * 📅 **Più recenti (Novità):** Ordina in base alla data di inserimento/modifica del file per ascoltare subito gli ultimi brani aggiunti.
  * 📅 **Meno recenti:** Cronologia classica.
  * 🔤 **Titolo (A - Z / Z - A):** Ordinamento alfabetico completo.
  * 👤 **Artista (A - Z):** Raggruppamento per artista.
  * **Riproduzione Sequenziale o Casuale (Shuffle Smart):** Tasto "Riproduci" per scorrere i brani nell'ordine scelto oppure "Casuale" (Shuffle). Quando lo shuffle è attivo, viene generata una coda casuale senza ripetizioni: tutti i brani vengono riprodotti esattamente una volta prima di ricominciare il ciclo.
* **Aggiornamenti In-App (OTA con Banner):**
  * Controllo automatico o manuale di nuove release su GitHub (`/releases/latest`).
  * Modalità dark dialog coerente con visualizzazione delle note di rilascio (changelog) e pulsante diretto per scaricare e installare l'APK.
  * Sistema di cache intelligente con TTL per evitare rate-limit GitHub.
* **Riproduzione in Background & Controlli Notifica:** Integra `audio_service` per una notifica multimediale persistente con controlli di riproduzione completi e sincronizzati anche a schermo spento.
* **Now Playing Screen Dedicata:**
  * Cover album / artwork con fallback dinamico.
  * Barra di avanzamento fluida (*Wavy Seek Bar*).
  * Modalità Shuffle e Loop (Loop One / Loop All).
* **Mini Player Persistente:** Barra inferiore sempre a portata di mano con equalizzatore animato.
* **Organizzazione della Libreria:**
  * Tab **Brani** con ricerca istantanea per titolo e artista.
  * Tab **Playlist** personalizzate.
  * Tab **Cartelle** configurate.
  * Accesso rapido ai **Brani Preferiti**.
* **Interfaccia Dark Moderna:** Design curato ispirato ai moderni player musicali (Material 3 Dark).

---

## 🚀 Architettura del Progetto

```
lib/
├── main.dart                  # Entry point, gestione tema e foreground service
├── models/
│   ├── playlist_model.dart    # Modello dati playlist
│   └── song_model.dart        # Modello brano, metadati e data file
├── services/
│   ├── audio_handler.dart     # AudioHandler (just_audio + audio_service)
│   ├── storage_service.dart   # Scansione filesystem, ordinamento e SharedPreferences
│   └── update_service.dart    # Client GitHub Releases API, cache e semver check
└── ui/
    ├── screens/
    │   ├── home_screen.dart           # Dashboard principale a tab (Brani, Playlist, Cartelle)
    │   └── now_playing_screen.dart    # Schermata del brano in riproduzione
    └── widgets/
        ├── animated_equalizer.dart    # Animazione barre equalizzatore
        ├── artwork_widget.dart        # Render cover/artwork
        ├── mini_player.dart           # Player compatto fisso in basso
        ├── song_tile.dart             # Elemento lista traccia
        ├── update_dialog.dart         # Banner/Dialog per aggiornamenti in-app
        └── wavy_seek_bar.dart         # Seekbar a onde
```

---

## 🛠️ Prerequisiti & Setup Locale

### Requisiti
* **Flutter SDK**: `>= 3.7.0` (testato su 3.29.0)
* **Dart SDK**: `^3.7.0`
* **Android SDK** con Java JDK 17 o 21 (Android NDK 27.0.12077973)

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
* **Trigger Manuale / Push:** Puoi lanciare la compilazione in qualsiasi momento dalla scheda *Actions* di GitHub con `workflow_dispatch` o push su `main`.

---

## 📄 Licenza
Distribuito sotto licenza MIT. Consulta il file [LICENSE](LICENSE) per ulteriori dettagli.
