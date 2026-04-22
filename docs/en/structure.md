# 📁 Project Structure 

```
project_root/
│
├── project.godot
├── icon.svg
│
├── scenes/                # All .tscn files (visual structure)
│   ├── board/
│   │   ├── board.tscn
│   │   └── tile.tscn
│   │
│   ├── units/
│   │   ├── base_unit.tscn
│   │   ├── leader.tscn
│   │   ├── major.tscn
│   │   ├── minor.tscn
│   │   └── pawn.tscn
│   │
│   ├── ui/
│   │   ├── hud.tscn
│   │   ├── ability_bar.tscn
│   │   └── draft_screen.tscn
│   │
│   └── effects/
│       ├── lightning.tscn
│       └── impact.tscn
│
├── scripts/               # Logic only
│   ├── core/
│   │   ├── game_manager.gd
│   │   ├── turn_manager.gd
│   │   ├── grid_manager.gd
│   │   └── input_manager.gd
│   │
│   ├── units/
│   │   └── unit.gd
│   │
│   ├── abilities/
│   │   ├── base_ability.gd
│   │   ├── lightning_strike.gd
│   │   ├── petrify.gd
│   │   └── dash.gd
│   │
│   └── ui/
│       └── hud.gd
│
├── assets/                # Raw files only (no logic)
│   ├── art/
│   │   ├── sprites/
│   │   │   ├── units/
│   │   │   │   ├── zeus.png
│   │   │   │   ├── medusa.png
│   │   │   │   └── ...
│   │   │   └── board/
│   │   │       └── tile.png
│   │   │
│   │   └── icons/
│   │       └── abilities/
│   │           ├── lightning.png
│   │           └── petrify.png
│   │
│   ├── models/            # If 3D later
│   │   └── units/
│   │       └── zeus.glb
│   │
│   └── audio/
│       ├── sfx/
│       └── music/
│
├── resources/             # Data (VERY important)
│   ├── units/
│   │   ├── zeus.tres
│   │   ├── medusa.tres
│   │   └── ...
│   │
│   └── abilities/
│       ├── lightning.tres
│       └── petrify.tres
│
├── autoload/              # Global singletons
│   ├── game_state.gd
│   └── signal_bus.gd
│
└── shaders/
    └── highlight.shader
```