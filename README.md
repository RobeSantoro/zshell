# zshell

Raccolta di piccoli script da riga di comando per macOS dedicati alla conversione di audio, immagini e PDF, oltre a semplici operazioni sui nomi dei file.

Gli script sono indipendenti: non esistono un processo di build, un package manager o una configurazione globale del progetto. Ogni utility può essere eseguita direttamente dalla directory del repository.

## Script disponibili

| Script | Funzione | Output predefinito | Dipendenze |
| --- | --- | --- | --- |
| `flac2mp3.sh` | Converte uno o più FLAC in MP3 e conserva metadati e copertine compatibili | Accanto al FLAC, con estensione `.mp3` | `ffmpeg` |
| `mkv2mp3.sh` | Estrae la prima traccia audio da uno o più MKV e la codifica in MP3 | Accanto all’MKV, con estensione `.mp3` | `ffmpeg` |
| `png2webp.sh` | Converte immagini PNG in WebP con qualità 80 | Accanto al PNG, con estensione `.webp` | `cwebp` |
| `jpg2webp.sh` | Converte immagini JPG/JPEG in WebP con qualità 80 | Accanto al JPG/JPEG, con estensione `.webp` | `cwebp` |
| `luma2alpha.sh` | Usa la luminanza invertita e ad alto contrasto come canale alpha | `<nome>_alpha.png` | ImageMagick |
| `flatpdf.sh` | Rasterizza e ricomprime un PDF alla risoluzione scelta | `<nome>_optimized.pdf` | Ghostscript, `img2pdf` |
| `prepend.sh` | Aggiunge un prefisso ai nomi di più file | File rinominati sul posto | Utility standard di macOS |

## Installazione

Su macOS, tutte le dipendenze possono essere installate con Homebrew:

```bash
brew install ffmpeg webp imagemagick ghostscript img2pdf
```

Gli script nel repository sono già eseguibili. In caso contrario:

```bash
chmod +x ./*.sh
```

## Conversione audio

### FLAC in MP3

```bash
./flac2mp3.sh brano.flac
./flac2mp3.sh *.flac
./flac2mp3.sh --quality 0 *.flac
./flac2mp3.sh --bitrate 320k *.flac
./flac2mp3.sh --output-dir ./mp3 *.flac
```

### MKV in MP3

`mkv2mp3.sh` usa la prima traccia audio dell’MKV, omette il video e conserva i metadati globali compatibili con MP3.

```bash
./mkv2mp3.sh registrazione.mkv
./mkv2mp3.sh *.mkv
./mkv2mp3.sh --quality 0 *.mkv
./mkv2mp3.sh --bitrate 320k --output-dir ./audio *.mkv
```

Le opzioni condivise dai due convertitori sono:

| Opzione | Significato |
| --- | --- |
| `-q N`, `--quality N` | Qualità VBR da 0, migliore, a 9, più compatta. Il valore predefinito è 2 |
| `-b RATE`, `--bitrate RATE` | Bitrate costante, per esempio `192k` o `320k` |
| `-o DIR`, `--output-dir DIR` | Directory di destinazione; viene creata se non esiste |
| `-f`, `--force` | Sovrascrive gli MP3 già presenti |
| `--delete-original`, `--DO` | Elimina la sorgente soltanto dopo una conversione riuscita |
| `-h`, `--help` | Mostra la guida completa |

È possibile anche passare come ultimo argomento una directory di destinazione già esistente:

```bash
./mkv2mp3.sh *.mkv ./audio_esistente
```

I convertitori audio scrivono prima in un file temporaneo e lo spostano nella destinazione soltanto al termine. Senza `--force`, un MP3 già esistente viene ignorato. Con `--delete-original`, file saltati o conversioni fallite non vengono eliminati.

## Conversione immagini

### PNG o JPG in WebP

```bash
./png2webp.sh *.png
./png2webp.sh *.png ./webp_esistenti

./jpg2webp.sh foto.jpg foto.jpeg
./jpg2webp.sh *.jpg ./webp_esistenti
```

L’ultimo argomento viene interpretato come destinazione soltanto se è una directory già esistente. La qualità WebP è attualmente fissata a 80.

### Luminanza nel canale alpha

```bash
./luma2alpha.sh immagine.png
```

Lo script aumenta fortemente il contrasto, inverte la luminanza e la usa come trasparenza: le aree chiare diventano più trasparenti, quelle scure più opache.

## Ottimizzazione PDF

```bash
./flatpdf.sh documento.pdf
./flatpdf.sh documento.pdf 200
```

Il secondo argomento è la risoluzione in DPI e vale 150 per impostazione predefinita. Il PDF viene rasterizzato pagina per pagina e poi ricostruito con il profilo Ghostscript `/ebook`.

> La rasterizzazione appiattisce testo, grafica vettoriale, link e altri elementi interattivi. Conservare sempre il PDF originale.

## Aggiunta di un prefisso

Il prefisso è sempre l’ultimo argomento:

```bash
./prepend.sh *.webp "IMG_"
```

Usare `prepend.sh` dalla directory che contiene i file e passare nomi relativi semplici. Lo script rinomina i file sul posto e non offre una modalità di anteprima.

## Finder Quick Actions

Gli script possono essere richiamati da Automator tramite un’azione **Esegui script shell**, usando `/bin/bash` e passando l’input come argomenti.

Su questa macchina le azioni installate si trovano in:

```text
~/Library/Services/
```

Le workflow di Automator non sono versionate in questo repository: contengono percorsi locali assoluti verso gli script. Dopo aver aggiunto o modificato una Quick Action, abilitarla da **Finder → Quick Actions → Customize…** oppure dalle impostazioni delle estensioni di macOS.

La Quick Action `Convert MKV to MP3` accetta genericamente elementi del Finder perché macOS Sonoma può non associare gli MKV a un tipo video standard; prima di eseguire `ffmpeg`, la workflow verifica comunque che ogni file abbia estensione `.mkv`.

## Sicurezza e sovrascrittura

- Usare `--delete-original` soltanto quando si desidera davvero rimuovere le sorgenti audio o video.
- `flac2mp3.sh` e `mkv2mp3.sh` proteggono gli output esistenti salvo uso esplicito di `--force`.
- Gli script WebP, `luma2alpha.sh`, `flatpdf.sh` e `prepend.sh` non implementano la stessa protezione completa: controllare in anticipo i nomi di destinazione.
- Racchiudere tra virgolette i percorsi contenenti spazi.

## Verifica rapida

Non è presente una test suite automatica. È possibile verificare almeno la sintassi con:

```bash
bash -n flac2mp3.sh jpg2webp.sh luma2alpha.sh mkv2mp3.sh png2webp.sh prepend.sh
zsh -n flatpdf.sh
```

Per la guida specifica di uno script che la supporta:

```bash
./mkv2mp3.sh --help
```
