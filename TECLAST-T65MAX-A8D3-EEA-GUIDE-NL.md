# Teclast T65 Max A8D3 EEA: Android/GSI-handleiding op macOS

> Werkdocument, getest op één `T65Max_EEA` met hardware/firmwarerevisie `A8D3` en stock-ROM `V1.05_20260305` (Android 14). Het ontgrendelen en de factory reset zijn uitgevoerd; de Android 16-GSI, root en TWRP zijn op het moment van schrijven nog niet geïnstalleerd. Deel dus nog geen ongeteste flashstappen als een voltooide procedure.

## Belangrijke waarschuwingen

- Gebruik dit uitsluitend voor **T65 Max A8D3 EEA**. Een andere revisie of regio kan andere preloader-, DA- en partitioneringsbestanden gebruiken.
- Bootloaderontgrendeling en het wissen van `userdata`/`metadata` verwijderen alle gebruikersgegevens.
- Maak vóór iedere wijziging een back-up van persoonlijke bestanden én van de MediaTek-kalibratiepartities.
- Flash nooit `preloader`, `nvram`, `nvdata`, `persist`, `proinfo`, `protect1/2`, `otp` of `seccfg` van een ander apparaat.
- Houd de officiële ROM beschikbaar om het apparaat te kunnen herstellen.
- Unieke USB-serienummers, ME_ID en SOC_ID horen niet in publieke logs of handleidingen.

## Geteste configuratie

- Model: `T65Max_EEA`
- Revisie: `A8D3`
- Stock build: `V1.05_20260305`
- Stock Android: 14 / API 34
- SoC: MediaTek MT6789/MT8781V (Helio G99)
- Architectuur: ARM64
- Kernel: Android 12 GKI 5.10.198
- Treble: ja
- A/B en Virtual A/B: ja
- Dynamische partities: ja
- `super`: 9 GiB
- Vendor: Android 12 / VNDK 31
- AVB: 1.2
- Correcte GSI-klasse: ARM64, A/B, system-as-root; doorgaans aangeduid als `arm64-ab` of `arm64-b*`

Android 16 is voor deze stock kernel/vendor-combinatie het verstandige eerste doel. Android 17 QPR1 en nieuwer ondersteunen Android 12-kernel 5.10 niet meer in de officiële Android-kernelmatrix.

## Benodigdheden op macOS

- Een betrouwbare USB-datakabel, liefst rechtstreeks op de Mac en niet via een hub
- Android Platform Tools (`adb` en `fastboot`)
- Python 3 en [mtkclient](https://github.com/bkerler/mtkclient)
- De officiële A8D3 EEA-firmware
- Voldoende vrije opslag voor persoonlijke en partitieback-ups

De bij deze test gebruikte officiële ROM was:

```text
T65Max(A8D3)_Android 14_V1.05_20260305_EEA_SZ.rar
SHA-256: 7f304ec93fd11c91a90d438b78e5a68102b8ae713b0cdf08d62d6d64bcd5939f
```

Uit die ROM werden onder andere gebruikt:

```text
Firmware/download_agent/DA_BR.bin
SHA-256: 7371562ba47111708da6508cb9ca239591b69577af95780f5de2a1db11c57456

Firmware/preloader_tb8781p1_64.bin
SHA-256: d93aa3609ba6762659dfd0bc7daa13373b3b75fbbc31edde8c9be27020865529
```

Controleer hashes altijd vóór gebruik.

## 1. Compatibiliteit uitlezen

Schakel Ontwikkelaarsopties, OEM-ontgrendeling en USB-foutopsporing in. Controleer daarna:

```sh
adb devices -l
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.treble.enabled
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.virtual_ab.enabled
adb shell getprop ro.boot.dynamic_partitions
adb shell uname -a
```

Ga alleen verder wanneer model, revisie, partitieschema en firmware overeenkomen.

## 2. Back-ups maken

Kopieer eerst gedeelde opslag en noteer geïnstalleerde pakketten:

```sh
adb pull /sdcard ./backup/shared-storage
adb shell pm list packages -3 > ./backup/installed-third-party-packages.txt
```

Een gewone ADB-back-up kan beveiligde appdata niet volledig lezen. Dat is normaal. Maak met mtkclient daarnaast afzonderlijke raw back-ups van ten minste:

```text
seccfg nvcfg nvdata persist protect1 protect2 proinfo nvram
csci dram_para flashinfo otp sec1 lk_a lk_b
```

Bewaar SHA-256-controlesommen en deel deze images nooit publiek: ze kunnen apparaatgebonden gegevens bevatten.

## 3. Betrouwbaar verbinden met mtkclient

Gebruik voor iedere opdracht exact de DA en preloader uit dezelfde A8D3 EEA-ROM. Voorbeeld vanuit de map van mtkclient:

```sh
python mtk.py \
  --loader /pad/naar/Firmware/download_agent/DA_BR.bin \
  --preloader /pad/naar/Firmware/preloader_tb8781p1_64.bin \
  gettargetconfig
```

Een succesvolle detectie op dit apparaat toont onder meer:

```text
CPU: MT6789/MT8781V(MTK Helio G99)
Detected regular mode
SBC enabled: False
SLA enabled: False
DAA enabled: False
Device is unprotected
```

### Handshake-tip voor deze tablet

Alleen knoppen vasthouden gaf vaak `Handshake failed, retrying...`. De meest betrouwbare methode tijdens deze test was:

1. Laat mtkclient eerst wachten.
2. Laat de volledig opgestarte tablet via `adb reboot` herstarten.
3. mtkclient vangt het korte PreLoader-venster tijdens de reboot.

Een shellvoorbeeld voor uitsluitend de uitleestest:

```sh
(sleep 3; adb reboot) & python mtk.py \
  --loader /pad/naar/DA_BR.bin \
  --preloader /pad/naar/preloader_tb8781p1_64.bin \
  gettargetconfig
```

Alternatief wanneer Android niet draait: laat mtkclient wachten, houd met aangesloten USB `Power` circa 15 seconden vast, laat los en druk geen volumeknop in.

## 4. Bootloaderstatus via `seccfg`

Op dit exemplaar verscheen geen bruikbare gewone bootloader-fastbootmodus; `adb reboot bootloader` kwam terug in Android. Fastbootd was wel bereikbaar, maar rapporteerde `unlocked: no` en kende de standaard unlock-opdracht niet.

Daarom werd na de volledige back-up mtkclient gebruikt om een wijziging van de V4-lockstatus in `seccfg` aan te vragen. De tool meldde:

```text
Detected V4 Lockstate
hwtype V4
Successfully wrote seccfg
```

Deze melding bleek op zichzelf **geen** bewijs van een blijvende ontgrendeling. Na de factory reset meldde Android `ro.boot.flash.locked=1`, Verified Boot bleef `green` en fastbootd meldde `unlocked: no`. Een nieuwe raw dump van `seccfg` had exact dezelfde SHA-256-hash als de oorspronkelijke back-up. De niet-kritieke wijziging werd bij het booten dus geweigerd of hersteld.

De gebruikte mtkclient-commit `0542a8729993000661e2325e838217ee754d1632` wijzigde de V4-werking: het oudere gedrag dat ook de dm-verity/critical-lockstatus wijzigt vereist nu `--critical`. Na afzonderlijke geïnformeerde toestemming genereerde `da seccfg unlock --critical` de juiste V4-structuur (`lock_state=3`, critical state `1`), maar ook deze gespecialiseerde XML-route liet ondanks haar succesmelding geen blijvende bytes achter.

De methode die op deze tablet werkelijk bleef staan was:

1. Laat dezelfde tablet met dezelfde gecontroleerde A8D3 EEA-loader zijn eigen 512-byte critical-unlockstructuur genereren. Een lokale diagnosepatch bewaarde de door mtkclient berekende `writedata` vóór de gespecialiseerde write.
2. Controleer in de kandidaatheader V4 `lock_state=3` en critical state `1`.
3. Schrijf dit apparaat-eigen bestand met de gewone partitieschrijver:

   ```sh
   python mtk.py \
     --loader /pad/naar/DA_BR.bin \
     --preloader /pad/naar/preloader_tb8781p1_64.bin \
     w seccfg seccfg-unlock-candidate.bin
   ```

4. Start een nieuwe MediaTek-sessie, dump de volledige `seccfg` en vergelijk de eerste 512 bytes met de kandidaat.
5. Herstart en verifieer drie onafhankelijke signalen: oranje bootwaarschuwing, Android `ro.boot.flash.locked=0`/`ro.boot.vbmeta.device_state=unlocked` en fastbootd `unlocked: yes`.

Op het geteste exemplaar was de SHA-256 van kandidaat/readback `397faa88b92cb85aa0dc99cc6fcfd16fbce456b1596b6191cb209c7311140e5f`. **Dit bestand is apparaat-specifiek: flash het bijbehorende bestand nooit op een andere tablet. Ieder apparaat moet zijn eigen cryptografische structuur genereren en verifiëren.**

## 5. `userdata` en `metadata` wissen

Voor het geteste apparaat werd na expliciete toestemming uitgevoerd:

```sh
python mtk.py \
  --loader /pad/naar/DA_BR.bin \
  --preloader /pad/naar/preloader_tb8781p1_64.bin \
  e userdata,metadata
```

Omdat de MediaTek XML-DA na de format-opdracht bleef wachten op een USB-slotantwoord, werden de partities ook afzonderlijk behandeld. De log bereikte:

```text
userdata: 100% Erasing
metadata: Formatting ... length 0x2000000
metadata: 100% Erasing
```

Belangrijk: 100% verwerking werd gezien, maar mtkclient ontving niet steeds een nette eindstatus. Dit bleek een apparaat-/DA-eigenaardigheid. Het wissen is daarna bevestigd doordat stock recovery de factory reset uitvoerde en Android het Welkom-scherm bereikte.

Na de directe erase kan stock recovery melden:

```text
Cannot load Android system. Your data may be corrupt.
```

Kies dan `Factory data reset`, bevestig en kies daarna `Reboot system now`. Hiermee maakt Android de encryptie- en filesystemmetadata correct opnieuw aan. De eerste start kan 5–10 minuten duren.

## 6. Nog te testen en documenteren

De volgende onderdelen zijn nog niet voltooid en mogen niet als bewezen stappen worden gedeeld:

- Bevestigen dat de bootloaderstatus na de factory reset daadwerkelijk `unlocked` is
- Een geschikte Android 16 ARM64 A/B-GSI selecteren en de downloadhash vastleggen
- AVB/vbmeta veilig behandelen
- De GSI via fastbootd naar de dynamische `system`-partitie schrijven
- Eerste boot, hardwarefuncties, mobiel netwerk, camera, audio en slaapstand testen
- Root via een met Magisk gepatchte eigen `init_boot`/`boot`-image
- Een apparaat-specifieke TWRP bouwen of verifiëren; installeer geen willekeurige TWRP-image

## Herstelstrategie

Bij een mislukte boot:

1. Stop met willekeurig flashen.
2. Gebruik uitsluitend de officiële A8D3 EEA-ROM en de bijbehorende scatter/DA/preloader.
3. Herstel eerst bootkritieke stock images (`boot`, `vendor_boot`, `vbmeta*`) volgens de officiële partitie-indeling.
4. Zet kalibratiepartities alleen terug vanuit de eigen apparaatback-up.
5. Flash nooit een preloader van een andere revisie.

## Status van deze praktijktest

- Compatibiliteitsanalyse: voltooid
- Officiële herstel-ROM veiliggesteld en hashes gecontroleerd: voltooid
- Persoonlijke opslag en kritieke partities geback-upt: voltooid
- Gewone en gespecialiseerde XML-`seccfg`-writes onderzocht; de apparaat-eigen critical-structuur bleef staan via generieke `w seccfg`
- `userdata` en `metadata` gewist, recovery-factory-reset voltooid en Android Welkom-scherm bereikt: bevestigd voltooid
- Bootloader na herstart: ontgrendeling bevestigd via oranje waarschuwing, Android-eigenschappen en fastbootd `unlocked: yes`
- Android 16-GSI: nog niet geflasht
- Root: nog niet uitgevoerd
- TWRP: nog niet gebouwd/geïnstalleerd
