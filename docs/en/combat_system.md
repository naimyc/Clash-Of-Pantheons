# ⚔️ Turn & Combat Timing System (15s Rounds)


## ⏱️ 1. Round Structure (15 seconds)

Each round always follows the same sequence:

## 🕒 Round Flow (15s)

### 1️⃣ Planning Phase (0–5s)
- Players choose:
  - 🚶 Movement
  - 🎯 Target attacks
  - ✨ Abilities (Deities / Mythos / Overgod)

---

### 2️⃣ Resolution Phase (5–12s)
Order:

1. 🐉 Mythos effects (environment activates)
2. 🏹 Ranged attacks
3. ⚔️ Melee combat
4. 🛡️ Defensive effects

---

### 3️⃣ Result Phase (12–15s)
- 💥 Damage is finalized
- ☠️ Units are removed
- 🧩 Formations are re-evaluated

---

# 🧠 2. Core Design Logic

## 🎯 Why this order?

- 🐉 Mythos changes the field first → affects everything after
- 🏹 Ranged uses the “altered world”
- ⚔️ Melee reacts to updated positions
- 🛡️ Defensive stabilizes the outcome

---

# 🐉 3. Mythos Timing (important!)

Mythos ALWAYS triggers first because:

👉 🌍 it changes the battlefield, not just units

### Example:

- 🐉 Hydra poisons a zone
- 🏹 then ranged units enter that zone → ☠️ damage occurs indirectly during combat

---

# ⚔️ 4. Combat Behavior (automatic)

Units act based on priority:

## 🎯 Target Priority

1. 🐉 Mythos (if reachable)
2. ✨ Deities
3. 🏹 Ranged units
4. ⚔️ Melee units
5. 🛡️ Defensive units

---

# 🧩 5. Movement Rules (7×3 important!)

- 🚶 Each unit moves max. **1–2 tiles per round**
- ⏱️ Movement happens **before attack resolution**
- 🚫 No double movement

---

<!--
# 🧱 6. Formation Check (very important)

At the end of each round:

- 🧠 Game checks:
  - 🧱 Is the frontline intact?
  - 👑 Is the Overgod protected?
  - 💔 Is the structure broken?

👉 If structure breaks:

- ❌ Formation bonus is deactivated
-->