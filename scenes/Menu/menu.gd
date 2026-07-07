# menu.gd — Hauptmenü-Skript für Clash of Pantheons
# Verwaltet: Pokale/Muenzen-Anzeige (aus PlayerData), Markt-Paneel, Arena-Anzeige,
# Spielmodus-Auswahl (Lokal/Multiplayer) und Szenenübergänge.

extends Control

# ---------------------------------------------------------------------------
# Knotenreferenzen
# ---------------------------------------------------------------------------

# TopBar
@onready var trophy_label     : Label          = $TopBar/Trophypanel/HBoxContainer/TrophyLabel
@onready var coins_label      : Label          = $TopBar/CoinsPanel/CoinsLabel
@onready var energy_label     : Label          = $TopBar/EnergyPanel/EnergyLabel

# Arena-Anzeige
@onready var arena_display    : PanelContainer = $ArenaDisplay
@onready var arena_name_label : Label          = $ArenaDisplay/VBoxContainer/ArenaNameLabel
@onready var arena_texture    : TextureRect    = $ArenaDisplay/VBoxContainer/ArenaTextureRect
@onready var arena_hint_label : Label          = $ArenaDisplay/VBoxContainer/ArenaHintLabel

# Welche Arena-Nummer gerade im Karussell angezeigt wird (per Mausrad durchblaetterbar).
# Kann von der tatsaechlich freigeschalteten Arena abweichen (Vorschau/Rueckblick).
var _viewed_arena : int = 1

# Hauptbutton
@onready var play_button      : Button         = $PlayButton

# BottomBar-Buttons
@onready var formation_button : Button         = $BottomBar/FormationButton
@onready var karten_button    : Button         = $BottomBar/GameButton
@onready var shop_button      : Button         = $BottomBar/ShopButton

# Schiebe-Paneel (nur noch der Markt; Formation ist jetzt eine eigene Szene)
@onready var shop_panel       : PanelContainer = $ShopPanel

# Shop-Inhalt
@onready var shop_liste       : VBoxContainer  = $ShopPanel/ShopVBox/ShopListe
@onready var muenzen_label    : Label          = $ShopPanel/ShopVBox/MuenzenLabel

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------

# Zeigt an ob das Markt-Paneel gerade geoeffnet ist (null = geschlossen)
var aktives_paneel   : PanelContainer = null

# Breite des Schiebe-Paneels in Pixeln
const PANEEL_BREITE  : float = 420.0

# Dauer der Ein-/Ausblend-Animation in Sekunden
const ANIMATIONS_DAUER : float = 0.25

# Modus-Auswahl-Popup (Lokal/Multiplayer), wird zur Laufzeit gebaut
var mode_choice_popup : PanelContainer = null
var mp_info_label     : Label = null

# ---------------------------------------------------------------------------
# _ready — wird aufgerufen wenn die Szene geladen ist
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Paneel verstecken und außerhalb des Bildschirms positionieren
	_paneele_initialisieren()
	_setup_mode_choice_popup()

	# Spielerdaten in der UI anzeigen
	_spielerdaten_aktualisieren()

	# Arena-Name setzen (dynamisch je nach Pokalen aus PlayerData)
	_viewed_arena = PlayerData.get_arena_info()["number"]
	arena_display.gui_input.connect(_on_arena_gui_input)
	_arena_aktualisieren()

	# Buttons mit Funktionen verbinden
	play_button.pressed.connect(_on_spielen_gedrueckt)
	formation_button.pressed.connect(_on_formation_gedrueckt)
	karten_button.pressed.connect(_on_karten_gedrueckt)
	shop_button.pressed.connect(_on_shop_gedrueckt)

	# Shop-Inhalt befuellen
	_shop_befuellen()

# ---------------------------------------------------------------------------
# Initialisierung des Schiebe-Paneels
# ---------------------------------------------------------------------------

func _paneele_initialisieren() -> void:
	# Shop-Paneel: rechts außerhalb des Bildschirms verstecken
	shop_panel.visible             = true
	shop_panel.anchor_left         = 1.0
	shop_panel.anchor_right        = 1.0
	shop_panel.offset_left         = 0.0
	shop_panel.offset_right        = PANEEL_BREITE

# ---------------------------------------------------------------------------
# Spielerdaten in der UI aktualisieren (aus PlayerData)
# ---------------------------------------------------------------------------

func _spielerdaten_aktualisieren() -> void:
	trophy_label.text   = str(PlayerData.trophies)
	coins_label.text    = "Muenzen: " + str(PlayerData.coins)
	energy_label.text   = "Energie: " + str(PlayerData.energy_points)
	muenzen_label.text  = "Muenzen: " + str(PlayerData.coins)

# ---------------------------------------------------------------------------
# Arena-Karussell — mit dem Mausrad durchblaetterbar
# Scrollen nach unten = vorherige (bereits abgeschlossene) Arena.
# Scrollen nach oben  = naechste Arena, als "in Bearbeitung" markiert.
# ---------------------------------------------------------------------------

func _arena_aktualisieren() -> void:
	var freigeschaltet : int = PlayerData.get_arena_info()["number"]
	var name := PlayerData.get_arena_name_for_number(_viewed_arena)

	if name == "":
		arena_name_label.text = "Arena %d\nin Bearbeitung" % _viewed_arena
	elif _viewed_arena < freigeschaltet:
		arena_name_label.text = name + "\n(abgeschlossen)"
	elif _viewed_arena == freigeschaltet:
		arena_name_label.text = name + "\n(aktuell)"
	else:
		arena_name_label.text = name

	arena_hint_label.text = "Mausrad: weitere Arenen ansehen"

func _on_arena_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	var freigeschaltet : int = PlayerData.get_arena_info()["number"]

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		# Nach unten scrollen -> vorherige Arena ansehen (nicht unter Arena 1).
		_viewed_arena = max(1, _viewed_arena - 1)
		_arena_aktualisieren()
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		# Nach oben scrollen -> naechste Arena ansehen (maximal eine Vorschau ueber die aktuelle hinaus).
		_viewed_arena = min(freigeschaltet + 1, _viewed_arena + 1)
		_arena_aktualisieren()

# ---------------------------------------------------------------------------
# MODUS-AUSWAHL (Lokal / Multiplayer)
# ---------------------------------------------------------------------------

func _setup_mode_choice_popup() -> void:
	mode_choice_popup = PanelContainer.new()
	mode_choice_popup.visible = false
	mode_choice_popup.set_anchors_preset(Control.PRESET_CENTER)
	mode_choice_popup.custom_minimum_size = Vector2(280, 160)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	mode_choice_popup.add_child(vbox)

	var titel := Label.new()
	titel.text = "Spielmodus waehlen"
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titel)

	var lokal_btn := Button.new()
	lokal_btn.text = "Lokal spielen"
	lokal_btn.custom_minimum_size = Vector2(0, 44)
	lokal_btn.pressed.connect(_on_lokal_gedrueckt)
	vbox.add_child(lokal_btn)

	var mp_btn := Button.new()
	mp_btn.text = "Multiplayer"
	mp_btn.custom_minimum_size = Vector2(0, 44)
	mp_btn.pressed.connect(_on_multiplayer_gedrueckt)
	vbox.add_child(mp_btn)

	mp_info_label = Label.new()
	mp_info_label.visible = false
	mp_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_info_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	vbox.add_child(mp_info_label)

	var schliessen_btn := Button.new()
	schliessen_btn.text = "Schliessen"
	schliessen_btn.pressed.connect(func(): mode_choice_popup.visible = false)
	vbox.add_child(schliessen_btn)

	add_child(mode_choice_popup)

func _on_lokal_gedrueckt() -> void:
	mode_choice_popup.visible = false
	get_tree().change_scene_to_file("res://scenes/Lobby/local_lobby.tscn")

func _on_multiplayer_gedrueckt() -> void:
	# Absichtlich funktionslos: kein Server vorhanden, es wird nie eine Szene gewechselt.
	mp_info_label.text = "Multiplayer nicht verfuegbar - kein Server"
	mp_info_label.visible = true

# ---------------------------------------------------------------------------
# BUTTON-FUNKTIONEN
# ---------------------------------------------------------------------------

# Spielen-Button: oeffnet die Spielmodus-Auswahl
func _on_spielen_gedrueckt() -> void:
	if aktives_paneel != null:
		_paneel_schliessen(aktives_paneel)
	mode_choice_popup.visible = true

# Formation-Button: wechselt zur eigenen Formation-Szene
func _on_formation_gedrueckt() -> void:
	get_tree().change_scene_to_file("res://scenes/Formation/formation_scene.tscn")

# Karten-Button: Platzhalter (kann spaeter zur Karten-Uebersicht fuehren)
func _on_karten_gedrueckt() -> void:
	if aktives_paneel != null:
		_paneel_schliessen(aktives_paneel)

# Shop-Button: oeffnet oder schliesst das Shop-Paneel
func _on_shop_gedrueckt() -> void:
	if aktives_paneel == shop_panel:
		_paneel_schliessen(shop_panel)
	else:
		_paneel_oeffnen(shop_panel)

# ---------------------------------------------------------------------------
# ANIMATION — Paneel von der Seite einfahren
# ---------------------------------------------------------------------------

func _paneel_oeffnen(paneel: PanelContainer) -> void:
	aktives_paneel = paneel

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)

	tween.tween_property(paneel, "offset_left",  -PANEEL_BREITE, ANIMATIONS_DAUER)
	tween.tween_property(paneel, "offset_right", 0.0,            ANIMATIONS_DAUER)

# ---------------------------------------------------------------------------
# ANIMATION — Paneel aus dem Bild herausfahren
# ---------------------------------------------------------------------------

func _paneel_schliessen(paneel: PanelContainer) -> void:
	aktives_paneel = null

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.set_parallel(true)

	tween.tween_property(paneel, "offset_left",  0.0,           ANIMATIONS_DAUER)
	tween.tween_property(paneel, "offset_right", PANEEL_BREITE, ANIMATIONS_DAUER)

# ---------------------------------------------------------------------------
# SHOP-PANEEL befuellen — verkauft Karten pro Charakter (kein Einmalkauf mehr)
# ---------------------------------------------------------------------------

func _shop_befuellen() -> void:
	for kind in shop_liste.get_children():
		kind.queue_free()

	muenzen_label.text = "Muenzen: " + str(PlayerData.coins)

	for unit_name in PlayerData.get_all_unit_stats().keys():
		var stats : UnitStats = PlayerData.get_all_unit_stats()[unit_name]
		var shop_karte := _shop_karte_erstellen(stats)
		shop_liste.add_child(shop_karte)

# ---------------------------------------------------------------------------
# HILFSFUNKTION — kaufbare Karte fuer den Shop erstellen
# ---------------------------------------------------------------------------

func _shop_karte_erstellen(stats: UnitStats) -> PanelContainer:
	var panel := PanelContainer.new()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Einheiten-Bild (gerendertes Portraet, falls vorhanden, sonst die rohe Skin-Textur)
	var portrait : Texture2D = stats.portrait_texture if stats.portrait_texture else stats.unit_texture
	if portrait != null:
		var bild := TextureRect.new()
		bild.texture             = portrait
		bild.custom_minimum_size = Vector2(48, 48)
		bild.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		bild.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(bild)

	# Name, Level und Kartenfortschritt
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.text = stats.unit_name
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "Level %d/%d" % [PlayerData.get_level(stats.unit_name), PlayerData.MAX_LEVEL]
	level_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(level_label)

	var karten_label := Label.new()
	var needed : int = PlayerData.cards_needed_for_next_level(stats.unit_name)
	karten_label.text = ("Karten: %d/%d" % [PlayerData.get_cards(stats.unit_name), needed]) if needed > 0 else "MAX LEVEL"
	karten_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(karten_label)

	var preis_label := Label.new()
	preis_label.text = str(PlayerData.CARD_COST_COINS) + " Muenzen/Karte"
	preis_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(preis_label)

	# Kaufen-Button
	var kauf_button := Button.new()
	kauf_button.text                = "Kaufen"
	kauf_button.custom_minimum_size = Vector2(80, 40)
	kauf_button.disabled            = PlayerData.get_level(stats.unit_name) >= PlayerData.MAX_LEVEL
	kauf_button.pressed.connect(_on_kaufen_gedrueckt.bind(stats.unit_name, kauf_button, karten_label))
	hbox.add_child(kauf_button)

	return panel

# ---------------------------------------------------------------------------
# KAUF-LOGIK — wird aufgerufen wenn "Kaufen" gedrueckt wird
# ---------------------------------------------------------------------------

func _on_kaufen_gedrueckt(unit_name: String, button: Button, karten_label: Label) -> void:
	if not PlayerData.buy_card(unit_name):
		_button_blinken(button, Color(0.9, 0.2, 0.2))
		return

	muenzen_label.text = "Muenzen: " + str(PlayerData.coins)
	coins_label.text   = "Muenzen: " + str(PlayerData.coins)

	var needed : int = PlayerData.cards_needed_for_next_level(unit_name)
	karten_label.text = ("Karten: %d/%d" % [PlayerData.get_cards(unit_name), needed]) if needed > 0 else "MAX LEVEL"

	_button_blinken(button, Color(0.2, 0.85, 0.2))

# ---------------------------------------------------------------------------
# HILFSFUNKTION — Button kurz in einer Farbe aufleuchten lassen
# ---------------------------------------------------------------------------

func _button_blinken(button: Button, farbe: Color) -> void:
	var original_farbe := button.get_theme_color("font_color") if button.has_theme_color("font_color") else Color.WHITE

	var tween := create_tween()
	tween.tween_method(
		func(c: Color): button.add_theme_color_override("font_color", c),
		original_farbe, farbe, 0.1
	)
	tween.tween_method(
		func(c: Color): button.add_theme_color_override("font_color", c),
		farbe, original_farbe, 0.3
	)
