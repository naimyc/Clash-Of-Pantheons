# player_data.gd — globaler Spielerstatus (Autoload "PlayerData")
# In-Memory only, keine Speicherung auf Festplatte (Prototyp).
extends Node

# ---------------------------------------------------------------------------
# FORMATION — 7 Spalten x 3 Reihen, row-major: index = row * FORMATION_COLS + col
# Reihe 0 = eigene Grundlinie, Reihe 2 = Front Richtung Gegner/Zentrum
# ---------------------------------------------------------------------------

const FORMATION_COLS := 7
const FORMATION_ROWS := 3
const FORMATION_SIZE := FORMATION_COLS * FORMATION_ROWS  # 21

# ---------------------------------------------------------------------------
# ZUSAMMENSETZUNG DER FORMATION (nach UnitClassData.typ_name)
# ---------------------------------------------------------------------------

const REQUIRED_K := 1   # Basilefs
const REQUIRED_G := 3   # Theoi — muessen 3 verschiedene Einheiten sein
const REQUIRED_P := 6   # Laos — Wiederholungen erlaubt
const REQUIRED_M := 1   # Mythos

# ---------------------------------------------------------------------------
# LEVEL-SYSTEM
# ---------------------------------------------------------------------------

const MAX_LEVEL := 3
const CARD_COST_COINS := 100  # Preis pro Karte, einheitlich fuer alle Einheiten

# Karten, die noetig sind um VOM aktuellen Level aufzusteigen (Level -> benoetigte Karten).
# Level 1->2 bewusst guenstig (5 Karten/500 Energie), damit man mit den Start-Ressourcen
# (800 Muenzen/500 Energie) sofort eine erste Einheit leveln kann. Summe bleibt bei 20
# Karten pro Charakter, damit die Balance "10 Charaktere in 200 Siegen maxen" stimmt.
const CARDS_FOR_LEVEL := {1: 5, 2: 15}

# ---------------------------------------------------------------------------
# BELOHNUNGEN PRO SIEG
# ---------------------------------------------------------------------------

const REWARD_TROPHIES := 30
const REWARD_COINS := 100
const REWARD_ENERGY_POINTS := 100

# ---------------------------------------------------------------------------
# ARENA-SCHWELLEN
# ---------------------------------------------------------------------------

const ARENA_2_THRESHOLD := 600

# ---------------------------------------------------------------------------
# SPIELERDATEN (in-memory, kein Save/Load)
# ---------------------------------------------------------------------------

var trophies: int = 600
var coins: int = 800
var energy_points: int = 500  # Level-Waehrung des Spielers — NICHT das Rundenelixier aus TurnManager

# unit_name (String) -> { "level": int, "cards": int }
var character_progress: Dictionary = {}

# 21 Zellen, "" = leer, sonst unit_name (String)
var formation: Array = []

# Transiente Aufstellungen fuer die aktuelle lokale Splitscreen-Partie (Lobby -> Battle).
# Werden bei jedem Lobby-Besuch aus "formation" kopiert, nie dauerhaft gespeichert.
var battle_formation_left: Array = []
var battle_formation_right: Array = []

# Welcher Modus zur aktuellen Partie gefuehrt hat ("local" oder "multiplayer") —
# wird von der Game-Over-Anzeige genutzt, um "Nochmal spielen" / "Anderen Modus spielen" zu zeigen.
var last_match_mode: String = "local"

# unit_name (String) -> UnitStats, einmal geladen, einzige Quelle fuer Einheiten-Ressourcen
var _unit_resources: Dictionary = {}

const _UNIT_PATHS: Array[String] = [
	"res://resources/unit/Zeus.tres",
	"res://resources/unit/Apollo.tres",
	"res://resources/unit/Hercules.tres",
	"res://resources/unit/Thanatos.tres",
	"res://resources/unit/Medusa.tres",
	"res://resources/unit/Archer.tres",
	"res://resources/unit/Knight.tres",
]


func _ready() -> void:
	_load_unit_resources()
	_init_default_progress()
	_init_default_formation()


func _load_unit_resources() -> void:
	for path in _UNIT_PATHS:
		var stats: UnitStats = load(path)
		if stats:
			_unit_resources[stats.unit_name] = stats


func _init_default_progress() -> void:
	for unit_name in _unit_resources.keys():
		character_progress[unit_name] = {"level": 1, "cards": 0}


func _init_default_formation() -> void:
	formation.resize(FORMATION_SIZE)
	for i in FORMATION_SIZE:
		formation[i] = ""

	# Reihe 0 = Grundlinie, Reihe 2 = Front — Standardaufstellung, bereits gueltig
	_place("Zeus", 3, 0)       # K
	_place("Apollo", 2, 0)     # G
	_place("Hercules", 4, 0)   # G
	_place("Thanatos", 3, 1)   # G
	_place("Medusa", 3, 2)     # M
	_place("Knight", 1, 0)     # P
	_place("Knight", 2, 1)     # P
	_place("Knight", 4, 1)     # P
	_place("Knight", 5, 0)     # P
	_place("Archer", 1, 2)     # P
	_place("Archer", 5, 2)     # P

	battle_formation_left = formation.duplicate()
	battle_formation_right = formation.duplicate()


func _place(unit_name: String, col: int, row: int) -> void:
	formation[row * FORMATION_COLS + col] = unit_name


# ---------------------------------------------------------------------------
# EINHEITEN-RESSOURCEN
# ---------------------------------------------------------------------------

func get_all_unit_stats() -> Dictionary:
	return _unit_resources


func get_unit_stats(unit_name: String) -> UnitStats:
	return _unit_resources.get(unit_name)


# ---------------------------------------------------------------------------
# KARTEN / LEVEL-OEKONOMIE
# ---------------------------------------------------------------------------

func get_level(unit_name: String) -> int:
	return character_progress.get(unit_name, {}).get("level", 1)


func get_cards(unit_name: String) -> int:
	return character_progress.get(unit_name, {}).get("cards", 0)


func cards_needed_for_next_level(unit_name: String) -> int:
	var lvl = get_level(unit_name)
	if lvl >= MAX_LEVEL:
		return 0
	return CARDS_FOR_LEVEL[lvl]


func energy_needed_for_next_level(unit_name: String) -> int:
	return cards_needed_for_next_level(unit_name) * CARD_COST_COINS


func can_buy_card(unit_name: String) -> bool:
	return coins >= CARD_COST_COINS and get_level(unit_name) < MAX_LEVEL


func buy_card(unit_name: String) -> bool:
	if not can_buy_card(unit_name):
		return false
	coins -= CARD_COST_COINS
	character_progress[unit_name]["cards"] += 1
	return true


func can_level_up(unit_name: String) -> bool:
	var lvl = get_level(unit_name)
	if lvl >= MAX_LEVEL:
		return false
	var needed_cards = cards_needed_for_next_level(unit_name)
	var needed_energy = energy_needed_for_next_level(unit_name)
	return get_cards(unit_name) >= needed_cards and energy_points >= needed_energy


func level_up(unit_name: String) -> bool:
	if not can_level_up(unit_name):
		return false
	var needed_cards = cards_needed_for_next_level(unit_name)
	var needed_energy = energy_needed_for_next_level(unit_name)
	character_progress[unit_name]["cards"] -= needed_cards
	energy_points -= needed_energy
	character_progress[unit_name]["level"] += 1
	return true


# ---------------------------------------------------------------------------
# SPIEL-BELOHNUNGEN
# ---------------------------------------------------------------------------

func add_match_rewards() -> void:
	trophies += REWARD_TROPHIES
	coins += REWARD_COINS
	energy_points += REWARD_ENERGY_POINTS


# ---------------------------------------------------------------------------
# ARENA
# ---------------------------------------------------------------------------

const ARENA_NAMES := {
	1: "Arena 1 - Olymp-Tore",
	2: "Arena 2 - Tartaros-Felder",
}

# Liefert die aktuell freigeschaltete Arena (abhaengig von den Pokalen).
func get_arena_info() -> Dictionary:
	var number: int = 1 if trophies < ARENA_2_THRESHOLD else 2
	return {"number": number, "name": ARENA_NAMES[number], "locked": false}

# Liefert den Namen einer beliebigen Arena-Nummer zum Durchblaettern (Karussell im Menue).
# Leerer String = noch nicht erstellt ("in Bearbeitung" wird vom Menue selbst angezeigt).
func get_arena_name_for_number(number: int) -> String:
	return ARENA_NAMES.get(number, "")


# ---------------------------------------------------------------------------
# FORMATION — GETTER/SETTER + VALIDIERUNG
# ---------------------------------------------------------------------------

func get_formation_cell(col: int, row: int) -> String:
	return formation[row * FORMATION_COLS + col]


func set_formation_cell(col: int, row: int, unit_name: String) -> void:
	formation[row * FORMATION_COLS + col] = unit_name


func validate_formation(candidate: Array) -> Dictionary:
	if candidate.size() != FORMATION_SIZE:
		return {"valid": false, "error": "Formation hat falsche Groesse."}

	var count_k := 0
	var count_m := 0
	var count_p := 0
	var count_g_total := 0
	var theoi_names := {}

	for cell in candidate:
		if cell == null or cell == "":
			continue

		var stats: UnitStats = _unit_resources.get(cell)
		if stats == null or stats.class_data == null:
			return {"valid": false, "error": "Unbekannte Einheit: %s" % str(cell)}

		match stats.class_data.typ_name:
			"K":
				count_k += 1
			"G":
				count_g_total += 1
				theoi_names[cell] = true
			"P":
				count_p += 1
			"M":
				count_m += 1
			_:
				return {"valid": false, "error": "Unbekannter Einheitentyp fuer %s" % cell}

	if count_k != REQUIRED_K:
		return {"valid": false, "error": "Es wird genau 1 Basilefs benoetigt (aktuell %d)." % count_k}
	if theoi_names.size() != REQUIRED_G or count_g_total != REQUIRED_G:
		return {"valid": false, "error": "Es werden genau 3 verschiedene Theoi benoetigt (aktuell %d)." % theoi_names.size()}
	if count_p != REQUIRED_P:
		return {"valid": false, "error": "Es werden genau 6 Laos-Platzierungen benoetigt (aktuell %d)." % count_p}
	if count_m != REQUIRED_M:
		return {"valid": false, "error": "Es wird genau 1 Mythos benoetigt (aktuell %d)." % count_m}

	return {"valid": true, "error": ""}


func commit_formation(candidate: Array) -> bool:
	var result = validate_formation(candidate)
	if not result["valid"]:
		return false
	formation = candidate.duplicate()
	return true
