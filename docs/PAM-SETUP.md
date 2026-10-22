# Fingerabdruck einrichten (Debian 13, KDE Plasma 6, SDDM)

Voraussetzungen: Die Pakete aus `packaging/build-deb.sh` sind installiert
(siehe `README.md`), und der Kernel bootet mit `spidev.bufsiz=65536`
(`sudo sh tools/grub-spidev.sh`, danach neu starten). Fehlt der Parameter,
meldet fprintd beim Öffnen: „spidev bufsiz is 4096, the image needs 24000“.

Das Passwort bleibt überall als Ausweg erhalten.

## 1. Finger einlernen

```
fprintd-enroll          # 20 Drücke, den Finger jedes Mal etwas anders auflegen
fprintd-verify          # Probe
```

Andere Finger: `fprintd-enroll -f left-index-finger` usw.
Löschen: `fprintd-delete $USER`.

## 2. sudo, Konsole und SDDM

```
sudo pam-auth-update --enable fprintd
```

Damit fragt `common-auth` zuerst den Fingerabdruck ab (bis zu 10 s,
ein Versuch) und fällt dann auf das Passwort zurück. Weil `sudo`, die
Konsole und `/etc/pam.d/sddm` alle `common-auth` einbinden, gilt das für
alle drei.

Rückgängig: `sudo pam-auth-update --disable fprintd`.

**Nur sudo** (getestet), SDDM und Konsole bleiben beim Passwort. Zur
Sicherheit vorher in einem zweiten Terminal `sudo -i` offen lassen:

```
sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak
sudo sed -i '/^@include common-auth/i auth sufficient pam_fprintd.so max-tries=1 timeout=10' /etc/pam.d/sudo
sudo -k; sudo true      # Probe
```

Rückgängig: `sudo cp /etc/pam.d/sudo.bak /etc/pam.d/sudo`.

**SDDM und KWallet:** `pam_kwallet5` entsperrt die Brieftasche nur mit dem
Passwort. Wer sich in SDDM per Finger anmeldet, wird danach von KWallet nach
dem Passwort gefragt. Wenn dich das stört, melde dich in SDDM mit Passwort an
und nutze den Finger nur für Sperrbildschirm und sudo.

## 3. KDE-Sperrbildschirm

Plasma 6 fragt den Finger parallel zum Passwortfeld über den eigenen
PAM-Dienst `kde-fingerprint` ab. Debian liefert ihn mit `libkscreenlocker6`
unter `/usr/lib/pam.d/kde-fingerprint` aus, es ist nichts anzulegen: Sobald
ein Finger eingelernt ist, genügt er auf dem Sperrbildschirm, das Passwortfeld
bleibt nutzbar.

Wer den Finger dort nicht möchte, legt eine abweisende Fassung an, die die
mitgelieferte überdeckt:

```
echo 'auth required pam_deny.so' | sudo tee /etc/pam.d/kde-fingerprint
```

Rückgängig: `sudo rm /etc/pam.d/kde-fingerprint`.

## Wenn es nicht geht

```
journalctl -u fprintd -b       # Meldungen des Treibers (goodixtls)
fprintd-list $USER
```

- „Device was already claimed“ (`AlreadyInUse`) kurz nach dem Entsperren
  oder Aufwachen: Der Sperrbildschirm hält den Sensor noch, bis die
  Fingerabfrage von `pam_fprintd` abläuft (bis zu 30 s), auch wenn mit dem
  Passwort entsperrt wurde. Kein Treiberfehler; abwarten.
- „unknown firmware …, please report“: Die Sensor-Firmware ist nicht in der
  Modelltabelle. Der Treiber schickt dann absichtlich keine weiteren Befehle.
- „reset: cannot open /dev/gpiochip0“: Das Drop-in
  `/usr/lib/systemd/system/fprintd.service.d/goodixtls.conf` fehlt, oder
  fprintd lief noch mit der alten Unit. Abhilfe:
  `sudo systemctl daemon-reload && sudo systemctl restart fprintd`.
