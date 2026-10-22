# Goodix GXFP5197 für Linux (Huawei MateBook D, VLT-W50)

Ein libfprint-Treiber (`goodixtls`) für den SPI-Fingerabdrucksensor
**Goodix GXFP5197** mit Firmware `GF3288_ST411SEC_APP_13010`, gebaut als
Debian-Paket von libfprint 1:1.94.9 (Debian 13 „trixie“). Über fprintd am
Gerät getestet: Einlernen, Prüfen (Treffer und Fehlversuch mit anderem
Finger), Entsperren des KDE-Sperrbildschirms direkt nach dem Aufwachen,
Prüfen nach einem Neustart und sudo per Finger. Die SDDM-Anmeldung nach
`docs/PAM-SETUP.md` ist nicht getestet.

Er beruht auf dem GXFP5187-Treiber von Benjamin Allègre (Sigfrodr) und
unterstützt diesen Sensor (MateBook X Pro, Firmware 11033) weiterhin. Beim
GXFP5197 ist dreierlei anders:

- **SPI:** Kopf und Rumpf jedes Frames gehen als zwei getrennte Transfers
  raus, mit 2 ms Abstand dazwischen. In einem Stück bleibt der Sensor stumm.
- **PSK-Adresse:** Der Schlüssel liegt bei `0x20007f14` statt `0x20007f0c`.
- **MCU-Zustand:** Nach dem TLS-Handshake muss der MCU-Zustand gesetzt sein,
  bevor die erste Fingerprüfung kommt.

## Was nötig ist

| | |
|---|---|
| Kernel-Parameter | `spidev.bufsiz=65536`, denn das Bild kommt in einem Transfer von etwa 22 kB. Setzen mit `sudo sh tools/grub-spidev.sh`, dann neu starten. |
| Pakete | `libfprint-2-2` aus diesem Projekt, dazu fprintd und libpam-fprintd aus Debian |

Das Paket bringt mit:

- eine udev-Regel, die den Sensor an spidev bindet (von libfprint erzeugt),
- ein systemd-Drop-in, das fprintd die Reset-Leitung (`/dev/gpiochip0`) erlaubt.

## Installieren

Fertiges Paket: `libfprint-2-2_1.94.9-1+gxfp5197.3_amd64.deb` aus den
Releases (Tag `v0.1.1`) laden, dann:

```
sudo apt install ./libfprint-2-2_1.94.9-1+gxfp5197.3_amd64.deb fprintd libpam-fprintd
sudo cp packaging/99-libfprint-goodixtls.pref /etc/apt/preferences.d/
sudo systemctl daemon-reload && sudo systemctl restart fprintd
```

## Selbst bauen

```
sudo sh tools/builddeps.sh        # Bauabhängigkeiten, einmalig
sh packaging/build-deb.sh         # ohne Root, Ergebnis in build/deb/
sudo sh packaging/install.sh      # installiert, setzt die Pin-Datei, startet fprintd neu
```

Der Treiber steckt vollständig im Patch
`packaging/patches/0100-goodixtls-gxfp5197.patch` (Verzeichnis
`libfprint/drivers/goodixtls/`); `build-deb.sh` holt die Debian-Quellen von
libfprint und wendet ihn an.

Danach weiter mit `docs/PAM-SETUP.md`.

Die Pin-Datei hält apt davon ab, das Paket bei einem Debian-Update durch
libfprint ohne GXFP5197 zu ersetzen. **Wenn Debian ein neues libfprint
bringt:** `VER`, `DEBVER` und `OURVER` in `packaging/build-deb.sh` anpassen,
den Patch prüfen (`packaging/patches/`), neu bauen, installieren und die
Pin-Datei auf die neue Version setzen. `apt policy libfprint-2-2` zeigt, ob
ein neueres Debian-Paket wartet.

## Sicherheitsmodell

- Der Abgleich läuft auf dem Rechner, nicht im Sensor. Die Vorlagen liegen,
  wie bei allen libfprint-Treibern dieser Art, unter `/var/lib/fprint`.
- Der TLS-Kanal zum Sensor schützt nichts gegen jemanden, der den SPI-Bus
  bedienen kann: Der Schlüssel wird aus dem RAM des Sensors gelesen. Er ist
  Verschleierung des Herstellers, keine Vertrauensgrenze.
- Gemessen: kein Fremdtreffer in 48 Vergleichen,
  15 % Zurückweisung pro Einzeldruck. Das ist eine kleine Stichprobe. Das
  Passwort bleibt der Ausweg, und für Dinge mit hohem Schutzbedarf ist der
  Finger kein Ersatz dafür.
- Der Treiber schreibt nie in den Flash des Sensors. Bei unbekannter Firmware
  bricht er ab, bevor er etwas anderes als lesende Befehle schickt.

## Herkunft und Lizenz

LGPL-2.1-or-later, wie libfprint.

- Treiberrahmen, TLS-Schicht, Abgleich (`goodix_sift.c`), Konfigurationsblock
  und Aufnahmesequenz: Sigfrodr,
  [libfprint-goodixtls](https://github.com/Sigfrodr/libfprint-goodixtls)
  (LGPL-2.1-or-later). Konfigurationsblock und Aufnahmesequenz sind dort
  mitgeschnittene Datenkonstanten. Der GXFP5197 nimmt sie unverändert an,
  die Prüfsumme des Blocks ist nachgerechnet.
- GXFP5197-spezifische Werte stammen aus eigener statischer Analyse der
  Firmware 13010 und des Windows-Treibers sowie aus Messungen am Gerät.
  Herstellermaterial liegt nicht im Repository.
- Vorarbeiten, aus denen gelernt wurde: szlukabence
  (goodix-fingerprint-spi-linux, GXFP51A0), GodsQuantum (MateBook-13-Treiber),
  goodix-fp-linux-dev (goodix-fp-dump).
