# libfprint-gxfp5197

Fingerprint driver for the **Goodix GXFP5197** SPI sensor
(ACPI HID `GXFP5197`) in the **Huawei MateBook D (VLT-W50)**, for
**Debian 13 (trixie)**. It also supports the GXFP5187 (ACPI HID `GXFP5187`,
MateBook X Pro).

Check: `ls /sys/bus/acpi/devices/ | grep GXFP`

[Deutsch weiter unten](#deutsch)

## Install

```
git clone https://github.com/fruchtpfote/libfprint-gxfp5197.git
cd libfprint-gxfp5197
sudo sh tools/grub-spidev.sh      # kernel parameter, then reboot
```

After the reboot, download `libfprint-2-2_…_amd64.deb` from
[Releases](https://github.com/fruchtpfote/libfprint-gxfp5197/releases) and run:

```
sudo apt install ./libfprint-2-2_1.94.9-1+gxfp5197.3_amd64.deb fprintd libpam-fprintd
sudo cp packaging/99-libfprint-goodixtls.pref /etc/apt/preferences.d/
sudo systemctl daemon-reload && sudo systemctl restart fprintd
fprintd-enroll
```

The `.pref` file stops Debian updates from replacing the driver.

## Use

- **KDE lock screen:** works by itself once a finger is enrolled.
- **sudo:**
  ```
  sudo sed -i '/^@include common-auth/i auth sufficient pam_fprintd.so max-tries=1 timeout=10' /etc/pam.d/sudo
  ```
  Undo: delete that line from `/etc/pam.d/sudo`.

Your password always keeps working.

## Good to know

- Right after unlocking with the password, the lock screen holds the sensor
  for up to 30 s ("Device was already claimed"). Just wait.
- Matching runs on the computer, not in the sensor. Fine for convenience,
  not a replacement for your password where security matters.
- The driver never writes to the sensor's flash.

## Build it yourself

```
sudo sh tools/builddeps.sh
sh packaging/build-deb.sh         # result in build/deb/
sudo sh packaging/install.sh
```

The driver is in `packaging/patches/0100-goodixtls-gxfp5197.patch`, applied
to Debian's libfprint 1:1.94.9-1.

## License

LGPL-2.1-or-later (see `COPYING`). Based on the GXFP5187 driver by
Benjamin Allègre (Sigfrodr),
[libfprint-goodixtls](https://github.com/Sigfrodr/libfprint-goodixtls).
GXFP5197 support by Matthias Gruss. Not affiliated with Goodix or Huawei.

---

## Deutsch

Fingerabdruck-Treiber für den SPI-Sensor **Goodix GXFP5197**
(ACPI-HID `GXFP5197`) im **Huawei MateBook D (VLT-W50)**, für
**Debian 13 (trixie)**. Der GXFP5187 (ACPI-HID `GXFP5187`, MateBook X Pro)
wird ebenfalls unterstützt.

Prüfen: `ls /sys/bus/acpi/devices/ | grep GXFP`

### Installieren

```
git clone https://github.com/fruchtpfote/libfprint-gxfp5197.git
cd libfprint-gxfp5197
sudo sh tools/grub-spidev.sh      # Kernel-Parameter, danach neu starten
```

Nach dem Neustart `libfprint-2-2_…_amd64.deb` unter
[Releases](https://github.com/fruchtpfote/libfprint-gxfp5197/releases) laden:

```
sudo apt install ./libfprint-2-2_1.94.9-1+gxfp5197.3_amd64.deb fprintd libpam-fprintd
sudo cp packaging/99-libfprint-goodixtls.pref /etc/apt/preferences.d/
sudo systemctl daemon-reload && sudo systemctl restart fprintd
fprintd-enroll
```

Die `.pref`-Datei verhindert, dass ein Debian-Update den Treiber ersetzt.

### Benutzen

- **KDE-Sperrbildschirm:** funktioniert von selbst, sobald ein Finger
  eingelernt ist.
- **sudo:**
  ```
  sudo sed -i '/^@include common-auth/i auth sufficient pam_fprintd.so max-tries=1 timeout=10' /etc/pam.d/sudo
  ```
  Rückgängig: die Zeile aus `/etc/pam.d/sudo` wieder löschen.

Das Passwort funktioniert immer weiter.

### Gut zu wissen

- Direkt nach dem Entsperren per Passwort hält der Sperrbildschirm den Sensor
  bis zu 30 s („Device was already claimed“). Einfach kurz warten.
- Der Abgleich läuft auf dem Rechner, nicht im Sensor. Bequem, aber kein
  Ersatz für das Passwort, wo es auf Sicherheit ankommt.
- Der Treiber schreibt nie in den Flash des Sensors.

### Selbst bauen

```
sudo sh tools/builddeps.sh
sh packaging/build-deb.sh         # Ergebnis in build/deb/
sudo sh packaging/install.sh
```

Der Treiber steckt in `packaging/patches/0100-goodixtls-gxfp5197.patch` und
wird auf Debians libfprint 1:1.94.9-1 angewendet.

### Lizenz

LGPL-2.1-or-later (siehe `COPYING`). Beruht auf dem GXFP5187-Treiber von
Benjamin Allègre (Sigfrodr). GXFP5197-Unterstützung: Matthias Gruss.
Keine Verbindung zu Goodix oder Huawei.
