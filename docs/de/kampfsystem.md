# ⚔️ Turn- & Kampf-Timing System (15s Runden)

## ⏱️ 1. Rundenstruktur (15 Sekunden)

Jede Runde läuft immer gleich ab:

## 🕒 Rundenablauf (15s)

### 1️⃣ Planung Phase (0–5s)
- Spieler wählen:
  - Bewegung
  - Zielangriffe
  - Fähigkeiten (Gottheiten / Mythos / Obergott)

---

### 2️⃣ Auflösungs Phase (5–12s)
Reihenfolge:

1. 🐉 Mythos-Effekte (Umwelt wird aktiv)
2. 🏹 Ranged Angriffe
3. ⚔️ Melee Kämpfe
4. 🛡️ Defensiv Effekte

---

### 3️⃣ Ergebnis Phase (12–15s)
- Schaden wird final berechnet
- Einheiten werden entfernt
- Formationen werden neu bewertet

---

# 🧠 2. Wichtige Design-Logik

## 🎯 Warum diese Reihenfolge?

* Mythos verändert zuerst das Feld → beeinflusst alles danach
* Ranged nutzt „veränderte Welt“
* Melee reagiert auf neue Positionen
* Defensiv stabilisiert das Ergebnis

---

# 🐉 3. Mythos Timing (wichtig!)

Mythos wirkt **IMMER zuerst**, weil:

👉 er das Spielfeld verändert, nicht nur Einheiten

### Beispiel:

* Hydra vergiftet Zone
* danach betreten Ranged Units diese Zone → Schaden passiert indirekt im Kampf

---

# ⚔️ 4. Kampfverhalten (automatisch)

Einheiten handeln nach Priorität:

## 🎯 Zielpriorität

1. 🐉 Mythos (wenn erreichbar)
2. ✨ Gottheiten
3. 🏹 Ranged Einheiten
4. ⚔️ Melee Einheiten
5. 🛡️ Defensiv Einheiten

---

# 🧩 5. Movement Regel (7×3 wichtig!)

* jede Einheit bewegt sich max. **1–2 Felder pro Runde**
* Bewegung passiert **vor Angriffsauswertung**
* keine doppelte Bewegung

---
<!--
# 🧱 6. Formations-Check (sehr wichtig)

Am Ende jeder Runde:

* 🧠 prüft Spiel:

  * Frontlinie intakt?
  * Obergott geschützt?
  * Struktur gebrochen?

👉 wenn Struktur bricht:

* ❌ Formationsbonus deaktiviert

---
-->