# LocalSongs 🎵

Un lettore musicale moderno, leggero e reattivo per Android sviluppato in **Flutter**. Progettato per riprodurre la propria libreria musicale offline memorizzata sul dispositivo, senza pubblicità, tracking o connessione internet richiesta.

---

## ✨ Funzionalità

### 🎶 Riproduzione & Audio Intelligente
* **Scansione Cartelle Personalizzate:** Scegli liberamente quali cartelle della memoria interna o microSD scansionare (MP3, FLAC, WAV, AAC, M4A, OGG, OPUS, WMA).
* **Filtro Audio Brevi (Anti-WhatsApp):** Escludi automaticamente note vocali di WhatsApp/Telegram, suonerie di sistema e notifiche sonore impostando una soglia minima (Nessun filtro, > 15s, > 30s, > 60s).
* **Ordinamento Flessibile dei Brani:**
  * 📅 **Più recenti (Novità):** Ordina in base alla data di inserimento/modifica del file per ascoltare subito gli ultimi brani aggiunti.
  * 📅 **Meno recenti:** Cronologia classica.
  * 🔤 **Titolo (A - Z / Z - A):** Ordinamento alfabetico completo.
  * 👤 **Artista (A - Z):** Raggruppamento per artista.
* **Shuffle Intelligente senza Ripetizioni:** Quando lo shuffle è attivo, viene generata una coda casuale dove ogni traccia viene riprodotta esattamente una volta prima di rimescolare il mazzo, garantendo zero ripetizioni precoci.
* **Equalizzatore di Sistema Nativo:** Tasto diretto per aprire il pannello equalizzatore ed effetti audio nativo del dispositivo (Android `AudioEffect` / Dolby Atmos).
* **Velocità di Riproduzione & Salto Configurabile:** Supporto a velocità 0.75x, 1.0x, 1.25x, 1.5x, 2.0x e salti avanti/indietro configurabili (5s, 10s, 15s, 30s).
* **Timer di Spegnimento (Sleep Timer):** Timer programmabile (15, 30, 45, 60 minuti) con spegnimento graduale automatico.

### 🚗 Modalità Guida (Car Mode)
* **Interfaccia ad Altissimo Contrasto:** Schermo intero immersivo con font e artwork giganti, ideale durante la guida.
* **Controlli Gesture a Tutto Schermo:**
  * **Tocco singolo:** Play / Pausa
  * **Swipe a sinistra:** Brano successivo
  * **Swipe a destra:** Brano precedente
  * **Doppio tocco:** Aggiungi / Rimuovi dai Preferiti con feedback aptico
* **Tasti Giganti Dedicati:** Pulsanti extralarge per chi preferisce un controllo tattile diretto.

### 🎨 Personalizzazione Grafica
* **Palette Accent Color Dinamica:** Personalizza il tema dell'applicazione scegliendo tra Verde Spotify, Ciano Elettrico, Viola Synthwave, Arancio Fuoco, Rosso Corallo, Giallo Oro, Rosa Neon o Blu Elettrico.
* **Nero Assoluto AMOLED:** Modalità sfondo `#000000` puro per esaltare i display OLED e minimizzare il consumo della batteria.
* **Stile Seekbar:** Alterna tra l'onda fluida animata (*Wavy Seek Bar*) in tempo reale e la barra lineare classica.

### 🧹 Utilità & Gestione File
* **Pulizia Titoli (Clean Titles 🧹):** Algoritmo intelligente che rimuove dai titoli tag spazzatura come `[Official Video]`, `(Lyrics)`, `[HQ]`, `yt1s.com`, `[SPOTIFY-DOWNLOADER.COM]`, ecc.
* **Condividi File MP3 📤:** Invia direttamente qualsiasi traccia audio ad altre applicazioni (WhatsApp, Telegram, Quick Share, Google Drive) tramite la share sheet nativa di Android.
* **Dettagli Tecnici Traccia:** Visualizza estensione/formato, dimensione esatta (KB/MB), data di modifica e percorso assoluto su disco.
* **Statistiche Libreria in Tempo Reale:** Monitora il numero totale di brani, i gigabyte occupati dai file audio, le cartelle configurate e le playlist create.
* **Svuotamento Cache Temporanea:** Pulisce con un tocco la cache temporanea e i file residui.

### 📦 Aggiornamenti In-App (OTA)
* Controllo automatico o manuale di nuove versioni su GitHub Releases (`/releases/latest`).
* Dialog Spotify Dark con visualizzazione formattata del changelog e download/installazione diretta dell'APK.
* Firma permanente garantita da keystore unificato locale e CI/CD.

---

## 🚀 Architettura del Progetto

```
lib/
├── main.dart                  # Entry point, reactive theme builder e foreground service
├── models/
│   ├── playlist_model.dart    # Modello dati playlist
│   └── song_model.dart        # Modello brano, metadati, file size e logica Clean Titles
├── services/
│   ├── audio_handler.dart     # AudioHandler (just_audio + audio_service + Equalizer bridge)
│   ├── settings_service.dart  # Controller preferenze (accent color, amoled, filtri, seekbar)
│   ├── storage_service.dart   # Scansione filesystem, filtri durata, statistiche e storage
│   └── update_service.dart    # Client GitHub Releases API, cache e semver check
└── ui/
    ├── screens/
    │   ├── home_screen.dart           # Dashboard principale a tab (Brani, Playlist, Cartelle)
    │   ├── now_playing_screen.dart    # Schermata brano corrente con opzioni e scorciatoia Car Mode
    │   ├── car_mode_screen.dart       # Modalità Guida a tutto schermo con gesture ovunque
    │   └── settings_screen.dart       # Centro impostazioni, grafica, equalizzatore e info
    └── widgets/
        ├── animated_equalizer.dart    # Animazione barre equalizzatore
        ├── artwork_widget.dart        # Render cover/artwork dinamico
        ├── mini_player.dart           # Player compatto fisso in basso
        ├── song_tile.dart             # Elemento lista traccia con share e info tecniche
        ├── update_dialog.dart         # Banner/Dialog per aggiornamenti in-app
        └── wavy_seek_bar.dart         # Seekbar a onda fluida con accent dinamico
```

---

## 🛠️ Prerequisiti & Setup Locale

### Requisiti
* **Flutter SDK**: `>= 3.7.0` (testato su 3.29.0)
* **Dart SDK**: `^3.7.0`
* **Android SDK** con Java JDK 17 o 21 (Android NDK `27.0.12077973`)

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
* **Trigger su Tag:** Quando crei un tag (es. `v1.0.3`), la pipeline compila l'APK release e crea automaticamente una nuova **GitHub Release** con l'APK pronto al download.
* **Keystore Permanente:** Compilato sempre con `signing.keystore` condiviso, per assicurare la perfetta compatibilità degli aggiornamenti OTA in-app su qualsiasi dispositivo senza errori di firma.

---

## 📄 Licenza

Rilasciato sotto licenza [MIT](LICENSE). Libero per uso personale e commerciale.
