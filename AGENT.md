# Istruzioni per gli agenti

## Ambito del repository

Questo repository contiene utility shell indipendenti per macOS. Non esistono build system, dipendenze vendorizzate o test automatici. Le modifiche devono rimanere piccole, leggibili e coerenti con lo scopo del singolo script.

Queste istruzioni si applicano all’intera directory del progetto.

## Mappa del progetto

- `flac2mp3.sh`: conversione FLAC → MP3 con `ffmpeg`, output temporaneo sicuro e cancellazione opzionale della sorgente.
- `mkv2mp3.sh`: estrazione della prima traccia audio MKV → MP3 con le stesse garanzie di `flac2mp3.sh`.
- `png2webp.sh` e `jpg2webp.sh`: conversione immagini con `cwebp`, qualità fissa a 80.
- `luma2alpha.sh`: composizione del canale alpha con ImageMagick.
- `flatpdf.sh`: rasterizzazione e ricompressione PDF; è l’unico script Zsh.
- `prepend.sh`: rinomina distruttiva sul posto aggiungendo un prefisso.
- `README.md`: documentazione utente e panoramica delle dipendenze.

## Regole di lavoro

1. Controllare sempre `git status --short` prima di modificare file. Il worktree può contenere file non tracciati o modifiche dell’utente: non eliminarli, non ripristinarli e non includerli accidentalmente in riscritture estese.
2. Conservare il bit eseguibile degli script.
3. Usare `/bin/bash` per gli script Bash e `/bin/zsh` per `flatpdf.sh`. Non introdurre funzionalità di Bash 4+: macOS distribuisce ancora una versione Bash precedente.
4. Quotare sempre espansioni e percorsi che possono contenere spazi. Preferire array per gli elenchi di file.
5. Verificare esplicitamente le dipendenze esterne con `command -v` e produrre errori comprensibili.
6. Non aggiungere nuove dipendenze se un’utility già disponibile nel progetto risolve il problema.
7. Mantenere in inglese help, messaggi CLI e commenti tecnici esistenti, salvo richiesta esplicita di localizzazione.
8. Evitare refactoring trasversali non richiesti: gli script hanno età e stili differenti e devono poter continuare a funzionare autonomamente.

## Invarianti di sicurezza

- Una conversione non deve distruggere un output valido o lasciare un file parziale.
- Per `flac2mp3.sh` e `mkv2mp3.sh`, conservare il flusso file temporaneo → verifica successo → spostamento finale.
- Non modificare il comportamento predefinito che salta gli MP3 esistenti. La sovrascrittura deve richiedere `--force`.
- La sorgente deve essere eliminata soltanto dopo una conversione e uno spostamento riusciti, e soltanto con `--delete-original` o `--DO`.
- Un errore, un file saltato o un input senza traccia audio non deve causare la cancellazione della sorgente.
- Per operazioni distruttive su file reali, usare fixture temporanee e non contenuti dell’utente.
- `flatpdf.sh` rasterizza il documento: non descrivere il risultato come equivalente semanticamente all’originale.

## Convenzioni CLI

- Supportare nomi di file con spazi.
- Se uno script accetta più file, continuare a elaborare gli altri input dopo un errore recuperabile e restituire un codice diverso da zero se almeno uno fallisce.
- Gli output diagnostici devono indicare chiaramente input, destinazione e motivo dell’errore.
- Le opzioni corte e lunghe già pubblicate sono API: non rimuoverle o cambiarne il significato senza una richiesta esplicita.
- Aggiornare `--help` e `README.md` quando cambia un’interfaccia utente.

## Validazione richiesta

Dopo ogni modifica eseguire almeno:

```bash
bash -n flac2mp3.sh jpg2webp.sh luma2alpha.sh mkv2mp3.sh png2webp.sh prepend.sh
zsh -n flatpdf.sh
git diff --check
```

Per lo script modificato aggiungere una prova funzionale proporzionata al rischio:

- Audio/video: creare una fixture breve in una directory ottenuta con `mktemp -d`, eseguire la conversione e ispezionare il risultato con `ffprobe`.
- Immagini: creare una piccola fixture temporanea, verificare formato, dimensioni e presenza del canale alpha quando rilevante.
- PDF: usare un PDF temporaneo di poche pagine e verificare numero di pagine e apertura dell’output.
- Rinomina: lavorare esclusivamente su copie temporanee e controllare i nomi finali.

Testare inoltre i casi di errore pertinenti: dipendenza mancante, estensione errata, output già esistente, file senza audio e percorsi contenenti spazi. Rimuovere le fixture create al termine.

## Automator e Finder

Le Quick Actions sono installate in `~/Library/Services` e non fanno parte del repository. Modificarle soltanto se la richiesta include esplicitamente l’integrazione Finder.

Le workflow locali richiamano gli script mediante percorsi assoluti: se il repository viene spostato, aggiornare anche il comando Automator. Usare `/bin/bash` e configurare **Pass input: as arguments**.

Su macOS Sonoma un MKV può non essere classificato come `public.movie`. La workflow `Convert MKV to MP3` usa quindi `public.item` per essere visibile, ma deve conservare il controllo interno case-insensitive dell’estensione `.mkv`.

Quando si abilita una Service come Quick Action, verificare entrambe le condizioni:

- la workflow è presente nel registro `pbs`;
- in `NSServicesStatus`, i valori `ContextMenu`, `FinderPreview`, `ServicesMenu` e `TouchBar` sono interi `1`, non stringhe `"1"`.

Dopo un aggiornamento, ricaricare la cache dei Services e rilanciare Finder. Preferire l’interfaccia **Quick Actions → Customize…** quando disponibile; non cambiare associazioni di apertura dei file, perché sono indipendenti dalle Quick Actions.

## Consegna

Riassumere i file modificati, i test eseguiti e gli eventuali rischi residui. Non dichiarare completata una modifica a una Quick Action soltanto perché appare sotto **Services**: su Sonoma va verificata anche la sua presenza nel sottomenu **Quick Actions**.
