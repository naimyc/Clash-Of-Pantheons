# 🎮 Clash of Pantheons – Game Design Document (GDD)

---

## 1. Überblick

**Spielname:** Clash of Pantheons  
**Genre:** Rundenbasierte Strategie  
**Plattform:** PC (optional Mobile)  
**Zielgruppe:** Strategie- und Mythologie-Fans  

### Core-Idee
Ein taktisches, gridbasiertes Strategiespiel, in dem Spieler Teams aus Göttern, Halbgöttern und Einheiten zusammenstellen, um den gegnerischen Gott zu besiegen.

---

## 1.2 Anforderungen & Präsentationsinhalte

### 🟢 1. Praktikumstermin – GDD (10 Minuten, max. 3%)

**Ziel:** Vorstellung der Spielidee und Konzeption

**Inhalte:**
- Spielidee & Konzept
- Name & Ziel des Spiels
- Kernmechaniken (Grid, Energie, Kampf)
- Einheitenarten (OberGott, Gottheiten, Mythos)
- Erste Skizzen / Mockups (z. B. Spielfeld, UI)
- Ggf. Assets:
  - Eigene Assets ODER
  - Quellen (z. B. kostenlose Asset-Packs)

---

### 🟡 2. Praktikumstermin – Gameplay (10 Minuten, max. 3%)

**Ziel:** Funktionierender Prototyp

**Inhalte:**
- Kurze Wiederholung der Idee
- Anpassungen am GDD (falls nötig)
- Erste spielbare Features:
  - Bewegung auf Grid
  - Erste Angriffe oder Fähigkeiten
- Demonstration des Prototyps
- Probleme & Herausforderungen
- Nächste Schritte

---

### 🔴 3. Praktikumstermin – Endprodukt (15 Minuten, max. 4%)

**Ziel:** Fertiges / erweitertes Spiel

**Inhalte:**
- Kurze Wiederholung der Idee
- Finaler Stand des Spiels
- Live-Demo:
  - Gameplay
  - Features
  - Game Juice (Animationen, Feedback, etc.)
- Verbesserungen & Bugfixes
- Ausgewählte Code-Snippets
- Lessons Learned

---

## 2. Gameplay

### Ziel
Besiege den gegnerischen Gott/ Pantheon Team.

### Spielablauf (Game Loop)

1. Energie erhalten  
2. Einheiten bewegen  
3. Angreifen  
4. Fähigkeiten nutzen  

---

## 3. Kernsysteme

### ⚡ Energie
- Wird pro Runde generiert
- Nutzung:
  - Fähigkeiten
  - Wiederbelebung

---

### 🔁 Rundensystem

1. Energiephase  
2. Bewegungsphase  
3. Aktionsphase  
4. Endphase  

---

### 🟦 Spielfeld

- Grid (z. B. 8x8)
- 1 Einheit pro Feld
- Optionen:
  - Hindernisse
  - Höhenunterschiede
  - Spezialfelder

---

## 4. Einheiten

### 👑 Basileus (Βασιλεύς Θεῶν) (K)
- 1 pro Team  
- Wichtigste Einheit  
- Bestimmt Spielstil  

---

### ✨ Theoi  (θεοὶ) (G)
- 3 pro Team  
- Starke Fähigkeiten  

---

### 🐉 Mythos (Μῦθος)  (M)
- Einzelne legendäre Kreatur / Wesen
- Beeinflussen die Umgebung/ Umwelt
- Starker Einfluss auf Kämpfe

---

### ⚔️ Laos (Λαός)(P)
- Schwächste Einheiten  
- Viele verfügbar  
- Günstig  

---

## 5. Kampfsystem

### Angriffe
- Basisangriffe (Melee / Ranged / Defensiv)
- Kein / geringer Energieverbrauch

### Fähigkeiten
- Kosten Energie
- Unterschiedliche Effekte:
  - Schaden
  - Buffs / Debuffs
  - Bewegung
  - Heilung

---

## 6. Wiederbelebung

- Einheiten können zurückgebracht werden
- Kosten abhängig vom Rang
- Götter können nicht revived werden

---

## 7. Pantheon Team - Building

- 1 Obergott
- 3 Gottheiten
- 1 Mythos
- 6 Pawns

👉 Gott bestimmt Strategie & Synergien

---

## 8. Spielmodi

- PvP (1v1)
- PvE (gegen KI)
- Story Mode

---

## 9. UI / UX (Konzept)

- Spielfeld zentral
- Fähigkeiten unten
- Energie oben
- Einheiteninfos seitlich

