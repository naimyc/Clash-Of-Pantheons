# Grid Input System (Godot Prototype)

## Overview
This system separates responsibilities for a clean grid-based tactics setup in Godot.

---

## 🧠 Core Structure

- **InputManager** → Handles mouse + raycasting  
- **GridManager** → Stores grid state + reacts to input  
- **Tile** → Stores position + visual highlight only  

---

## 🏗 Scene Setup

```
BattleScene
├── GridManager
├── InputManager
├── Camera3D
├── Units
```

---

## 🎮 InputManager

Handles:
- Mouse position
- Raycasting
- Detecting hovered tile

Calls GridManager when tile changes.

---

## 🧩 GridManager

Handles:
- Tile storage
- Hover state updates
- Grid logic (future movement / occupancy)

Example:
- on_tile_hovered(tile)
- clear_hover()

---

## 🟦 Tile

Handles:
- grid position
- occupancy state
- highlight visibility

No input or raycasting logic.

---

## 🔁 Hover Flow

Mouse → InputManager → Raycast → Tile → GridManager → Highlight

---

## ⚙️ Key Rule

> Input, logic, and visuals are separated.

This keeps the system scalable for:
- movement
- combat
- abilities
- AI