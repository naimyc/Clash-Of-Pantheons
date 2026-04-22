# 🧱 Clash Of Pantheons – Godot Project Structure

This document defines the recommended project structure for **Clash Of Pantheon** in Godot.  
The goal is scalability, clarity, and clean separation between logic, data, and assets.

---

## 📁 Root Structure

```plaintext
project_root/
│
├── project.godot
├── icon.svg
│
├── scenes/
├── scripts/
├── assets/
├── resources/
├── autoload/
└── shaders/
```
## Guidelines
- Scenes must contain no gameplay logic
- Use them as reusable building blocks
- All units inherit from base_unit.tscn

---

## 🎬 Scenes (`/scenes`)

Scenes represent **visual structure and composition only**.

```
scenes/
├── board/
│ ├── board.tscn
│ └── tile.tscn
│
├── units/
│ ├── base_unit.tscn
│ ├── leader.tscn
│ ├── major.tscn
│ ├── minor.tscn
│ └── pawn.tscn
│
├── ui/
│ ├── hud.tscn
│ ├── ability_bar.tscn
│ └── draft_screen.tscn
│
└── effects/
├── lightning.tscn
└── impact.tscn
```

---

## 🧠 Scripts (`/scripts`)

Scripts define **game logic and behavior**.

```
scripts/
├── core/
│ ├── game_manager.gd
│ ├── turn_manager.gd
│ ├── grid_manager.gd
│ └── input_manager.gd
│
├── units/
│ └── unit.gd
│
├── abilities/
│ ├── base_ability.gd
│ ├── lightning_strike.gd
│ ├── petrify.gd
│ └── dash.gd
│
└── ui/
└── hud.gd
```

### Guidelines
- Keep logic separate from scenes.
- Avoid creating one script per unit (e.g. `zeus.gd` ❌).
- Use shared base classes (`unit.gd`, `base_ability.gd`).

---

## 🎨 Assets (`/assets`)

Raw imported files only (no logic).

```
assets/
├── art/
│ ├── sprites/
│ │ ├── units/
│ │ │ ├── zeus.png
│ │ │ ├── medusa.png
│ │ │ └── ...
│ │ │
│ │ └── board/
│ │ └── tile.png
│ │
│ └── icons/
│ └── abilities/
│ ├── lightning.png
│ └── petrify.png
│
├── models/
│ └── units/
│ └── zeus.glb
│
└── audio/
├── sfx/
└── music/
```

### Guidelines
- Do not mix scripts or scenes here.
- Group by **type first**, then by purpose.

---

## 📦 Resources (`/resources`)

Data-driven configuration (**VERY IMPORTANT**).

```
resources/
├── units/
│ ├── zeus.tres
│ ├── medusa.tres
│ └── ...
│
└── abilities/
├── lightning.tres
└── petrify.tres
```

### Why this matters
- Units and abilities are defined as **data**, not hardcoded logic.
- Enables:
  - fast balancing
  - easy expansion
  - clean drafting system

---

## ⚡ Example Unit Resource

```
[resource]
name = "Zeus"
type = "Leader"
health = 10
move_range = 2
ability = preload("res://scripts/abilities/lightning_strike.gd")
icon = "res://assets/art/sprites/units/zeus.png"
```
---

### Usage in code
```
gdscript
unit_data.health
unit_data.ability
```
---
## 🌐 Autoload (/autoload)
Global singleton scripts.

```
autoload/
├── game_state.gd
└── signal_bus.gd
```
## Purpose
- Shared state (turns, match state)
- Global signals (communication between systems)

---
## ✨ Shaders (/shaders)
```
shaders/
└── highlight.shader
```

Used for:

- tile highlighting
- selection effects
- visual feedback
---
## 🧩 Scene Design Patterns
### Base Unit Scene
```
BaseUnit (Node2D)
├── Sprite2D
├── CollisionShape2D
└── Highlight
```

All units inherit from this base scene
### Board Scene
```
Board (Node2D)
├── GridManager
├── Tiles (instanced or generated)
└── Units (container node)
```
---
## 🚫 Common Mistakes
- Mixing scripts, scenes, and assets
- Hardcoding unit logic
- Creating one script per character
- Putting gameplay logic inside UI
---
## 📛 Naming Conventions
- Use snake_case
- Match scene and script names when possible
- Keep paths predictable and consistent
---
## ✅ Summary
- Scenes = structure
- Scripts = logic
- Assets = raw media
- Resources = gameplay data

This separation keeps the project maintainable as it scales.