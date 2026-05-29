extends Node
class_name GridManager

# --- KONSTANTEN UND CONFIG ---
const GRID_SIZE = 7
const TILE_SIZE = 1.0

# --- EXPORTIERTE SZENEN ---
@export var tile_scene: PackedScene = preload("res://scenes/tile/tile.tscn")
@export var figure_scene: PackedScene = preload("res://scenes/figure/figure.tscn")

# --- INTERNE SPEICHERUNG ---
var tiles = {}
var hovered_tile = null
var selected_tile = null
var selected_figure: Figure = null
var active_indicators: Array = []

# --- REFERENZEN ---
@onready var input_manager = $"../InputManager"

# --- INITIALISIERUNG ---
func _ready():
	# Generiert das Spielfeld und verbindet Eingabesignale
	generate_grid()
	
	if input_manager:
		input_manager.tile_hovered.connect(_on_tile_hovered)
		input_manager.tile_unhovered.connect(_on_tile_unhovered)
		input_manager.tile_clicked.connect(_on_tile_clicked)
		
	spawn_starting_figures()

# Generiert das 7x7 Schachbrettmuster auf dem Schlachtfeld
func generate_grid():
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var tile = tile_scene.instantiate()
			var mesh = tile.get_node("MeshInstance3D")
			var material = StandardMaterial3D.new()

			# Erzeugt das wechselnde Hell/Dunkel-Muster
			if (x + z) % 2 == 0:
				material.albedo_color = Color(0.8, 0.8, 0.8)
			else:
				material.albedo_color = Color(0.2, 0.2, 0.2)

			mesh.material_override = material

			# Zentriert das gesamte Gitter um den Nullpunkt (0,0,0)
			tile.position = grid_to_world(Vector2i(x, z))
			tile.grid_position = Vector2i(x, z)

			add_child(tile)
			if input_manager:
				input_manager.register_tile(tile)
			tiles[Vector2i(x, z)] = tile

# Hilfsfunktion, um Grid-Koordinaten in Welt-Koordinaten umzuwandeln
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		(grid_pos.x - GRID_SIZE / 2.0) * TILE_SIZE,
		0,
		(grid_pos.y - GRID_SIZE / 2.0) * TILE_SIZE
	)

func get_tile(coord: Vector2i):
	return tiles.get(coord)

# Setzt alle Figuren zu Kampfbeginn an ihre exakten Startpositionen
func spawn_starting_figures():
	# Ressourcen laden (Achte darauf, dass die Namen exakt deinen .tres Dateien entsprechen!)
	var knight_stats = load("res://resources/unit/Knight.tres")
	var archer_stats= load("res://resources/unit/Archer.tres")
	var apollo_stats= load("res://resources/unit/Apollo.tres")
	var hercules_stats= load("res://resources/unit/Hercules.tres")
	var thanatos_stats = load("res://resources/unit/Thanatos.tres")
	var zeus_stats = load("res://resources/unit/Zeus.tres")
	var medusa_stats = load("res://resources/unit/Medusa.tres")

	# TEAM 0 (Gegner - Oben auf dem Feld: Z = 0, 1, 2)
	if knight_stats: spawn_figure(Vector2i(1, 1), 0, knight_stats)
	if knight_stats: spawn_figure(Vector2i(2, 1), 0, knight_stats)
	if knight_stats: spawn_figure(Vector2i(4, 1), 0, knight_stats)
	if knight_stats: spawn_figure(Vector2i(5, 1), 0, knight_stats)
	if archer_stats: spawn_figure(Vector2i(1, 0), 0, archer_stats)
	if archer_stats: spawn_figure(Vector2i(5, 0), 0, archer_stats)
	if medusa_stats: spawn_figure(Vector2i(3, 2), 0, medusa_stats)
	if thanatos_stats: spawn_figure(Vector2i(2, 0), 0, thanatos_stats)
	if apollo_stats: spawn_figure(Vector2i(4, 0), 0, apollo_stats)
	if hercules_stats: spawn_figure(Vector2i(3, 1), 0, hercules_stats)
	if zeus_stats: spawn_figure(Vector2i(3, 0), 0, zeus_stats)
	
	# TEAM 1 (Spieler - Unten auf dem Feld: Z = 4, 5, 6)
	if knight_stats: spawn_figure(Vector2i(1, 5), 1, knight_stats)
	if knight_stats: spawn_figure(Vector2i(2, 5), 1, knight_stats)
	if knight_stats: spawn_figure(Vector2i(4, 5), 1, knight_stats)
	if knight_stats: spawn_figure(Vector2i(5, 5), 1, knight_stats)
	if archer_stats: spawn_figure(Vector2i(1, 6), 1, archer_stats)
	if archer_stats: spawn_figure(Vector2i(5, 6), 1, archer_stats)
	if medusa_stats: spawn_figure(Vector2i(3, 4), 1, medusa_stats)
	if thanatos_stats: spawn_figure(Vector2i(4, 6), 1, thanatos_stats)
	if apollo_stats: spawn_figure(Vector2i(2, 6), 1, apollo_stats)
	if hercules_stats: spawn_figure(Vector2i(3, 5), 1, hercules_stats)
	if zeus_stats: spawn_figure(Vector2i(3, 6), 1, zeus_stats)

func spawn_figure(target_cell: Vector2i, team: int, stats_resource: UnitStats):
	var new_figure = figure_scene.instantiate()
	new_figure.stats = stats_resource
	new_figure.team = team 
	new_figure.grid_manager = self
	new_figure.position = grid_to_world(target_cell)
	new_figure.grid_position = target_cell 
	
	var tile = get_tile(target_cell)
	if tile:
		tile.occupied = true
		tile.occupying_unit = new_figure
		new_figure.current_tile = tile 
	
	add_child(new_figure)
	
	var model = new_figure.get_node_or_null("FigureBody/model")
	if model and model.has_method("apply_skin") and stats_resource.unit_texture:
		model.apply_skin(stats_resource.unit_texture)

# --- EINGABE-VERARBEITUNG ---
func _on_tile_hovered(tile):
	if tile == selected_tile: return
	hovered_tile = tile
	tile.set_highlight(true)

func _on_tile_unhovered(tile):
	if tile == selected_tile: return
	if hovered_tile == tile: hovered_tile = null
	tile.set_highlight(false)

# --- NEUES SYSTEM: WEGEBERECHNUNG UND REICHWEITEN ---

# Berechnet alle begehbaren Felder mittels Breitensuche (BFS) ohne Figuren zu überspringen
func get_valid_moves(figure: Figure) -> Array[Vector2i]:
	var valid_tiles: Array[Vector2i] = []
	if figure == null or figure.stats == null or figure.stats.class_data == null:
		return valid_tiles
		
	var start_pos = figure.grid_position
	var max_range = figure.stats.move_range
	var move_type = figure.stats.class_data.movement_type # "Orthogonal" oder "all"
	
	var directions: Array[Vector2i] = []
	
	if move_type == "Orthogonal" or move_type == "all":
		directions.append(Vector2i.UP)
		directions.append(Vector2i.DOWN)
		directions.append(Vector2i.LEFT)
		directions.append(Vector2i.RIGHT)
		
	if move_type == "all":
		directions.append(Vector2i(1, 1))
		directions.append(Vector2i(1, -1))
		directions.append(Vector2i(-1, 1))
		directions.append(Vector2i(-1, -1))
	
	var queue = []
	queue.append({"pos": start_pos, "dist": 0})
	
	var visited = {}
	visited[start_pos] = true
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var curr_pos = current["pos"]
		var curr_dist = current["dist"]
		
		if curr_pos != start_pos:
			valid_tiles.append(curr_pos)
			
		if curr_dist >= max_range:
			continue
			
		for dir in directions:
			var next_pos = curr_pos + dir
			
			if not visited.has(next_pos):
				var tile = get_tile(next_pos)
				
				if tile == null:
					continue
					
				# LOGIK GEGEN ÜBERSPRINGEN: Wenn besetzt, endet der Weg hier
				if tile.occupied:
					continue
				
				visited[next_pos] = true
				queue.append({"pos": next_pos, "dist": curr_dist + 1})
				
	return valid_tiles


func clear_indicators():
	for tile in active_indicators:
		if is_instance_valid(tile):
			tile.set_color_mode("normal")
	active_indicators.clear()

func deselect_everything():
	if selected_figure:
		selected_figure.set_selected(false)
	
	selected_figure = null
	clear_indicators()
	
	var game_ui = get_node_or_null("%GameUI")
	if game_ui:
		game_ui.display_figure_stats(null)

# Wird am Rundenwechsel vom TurnManager aufgerufen, um Bewegungsrechte zu erneuern
func reset_all_movements():
	clear_indicators()
	
	for child in get_children():
		if child is Figure or "has_moved_this_round" in child:
			child.has_moved_this_round = false
			child.has_attacked_this_round = false # FIX: Auch Angriff zurücksetzen!
			
	var figures_node = get_node_or_null("../Figures")
	if figures_node:
		for figure in figures_node.get_children():
			if "has_moved_this_round" in figure:
				figure.has_moved_this_round = false

# 1. ANGRIFFSBERECHNUNG (Fixt das Problem mit der Sichtlinie)
func get_valid_attacks(figure: Figure) -> Array[Vector2i]:
	var valid_attacks: Array[Vector2i] = []
	if figure == null or figure.stats == null: return valid_attacks
		
	var start_pos = figure.grid_position
	var max_range = figure.stats.attack_range if "attack_range" in figure.stats else 1
	var directions = [Vector2i(0, 1), Vector2i(0, -1)] # Nur vorne und hinten
	
	for dir in directions:
		for i in range(1, max_range + 1):
			var target_pos = start_pos + dir * i
			var tile = get_tile(target_pos)
			if tile == null: break
				
			if tile.occupied:
				var target_unit = tile.occupying_unit
				# FIX: Wenn es ein Feind ist, wird das Feld als ZIEL hinzugefügt!
				if target_unit and target_unit.team != figure.team:
					valid_attacks.append(target_pos)
				# Der Strahl bricht in BEIDEN Fällen ab (Freund oder Feind blockiert weitere Sicht)
				break 
	return valid_attacks

# 2. INDIKATOREN (Zeigt Blau für Bewegung, Gelb für Angriff - getrennt!)
func show_indicators_for(figure: Figure):
	clear_indicators()
	
	# Zeigt blaue Felder nur, wenn sich die Figur noch NICHT bewegt hat
	if not figure.has_moved_this_round:
		var valid_moves = get_valid_moves(figure)
		for pos in valid_moves:
			var tile = get_tile(pos)
			if tile:
				tile.set_color_mode("move_target")
				active_indicators.append(tile)
			
	# Zeigt gelbe Felder nur, wenn die Figur noch NICHT angegriffen hat
	if not figure.has_attacked_this_round:
		var valid_attacks = get_valid_attacks(figure)
		for pos in valid_attacks:
			var tile = get_tile(pos)
			if tile:
				tile.set_color_mode("attack_target") # WICHTIG: Muss im tile.gd Gelb sein!
				active_indicators.append(tile)

# 3. FIGUR AUSWÄHLEN (Erlaubt jetzt das Inspizieren von Gegnern ohne Steuerungsrechte)
func select_figure(clicked_figure: Figure):
	var turn_manager = get_node_or_null("%TurnManager")
	var game_ui = get_node_or_null("%GameUI")
	if not turn_manager: return
	
	var ist_spieler_zug = (turn_manager.active_player == turn_manager.player_one)
	
	# --- ANGRIFFS-LOGIK ---
	# Wenn wir eine EIGENE Figur ausgewählt haben, diese noch nicht angegriffen hat,
	# und wir im eigenen Zug direkt auf einen GEGNER klicken:
	if selected_figure != null and selected_figure.team == 1 and clicked_figure.team != 1 and ist_spieler_zug:
		if not selected_figure.has_attacked_this_round:
			var valid_attacks = get_valid_attacks(selected_figure)
			
			# Steht der Feind auf einem der Angriffsfelder (Gelb)?
			if clicked_figure.grid_position in valid_attacks:
				var cost = selected_figure.stats.class_data.elixir_cost_atk if selected_figure.stats.class_data else 1
				
				if turn_manager.active_player.current_energy >= cost:
					var damage = selected_figure.stats.attack if "attack" in selected_figure.stats else 10
					clicked_figure.current_hp -= damage
					
					selected_figure.has_attacked_this_round = true
					turn_manager.spend_energy(cost)
					
					print("Angriff! Gegner ", clicked_figure.stats.unit_name, " verbleibende HP: ", clicked_figure.current_hp)
					
					# Wenn der Gegner stirbt, löschen wir ihn vom Feld
					if clicked_figure.current_hp <= 0:
						var t = clicked_figure.current_tile
						if t: 
							t.occupied = false
							t.occupying_unit = null
						clicked_figure.queue_free()
						deselect_everything()
					else:
						# Wenn er überlebt, aktualisieren wir sofort seine Lebenspunkte im UI
						if game_ui:
							game_ui.display_figure_stats(clicked_figure)
						# Zeigt die Reichweiten der eigenen Figur neu an (falls noch Bewegung offen ist)
						show_indicators_for(selected_figure)
					return 
				else:
					print("Nicht genügend Elixier für einen Angriff!")
					return

	# --- AUSWAHL-LOGIK (FÜR STATISTIKEN-VORSCHAU) ---
	# Wenn kein Angriff stattfindet, wechseln wir die Auswahl auf die angeklickte Figur
	if selected_figure != clicked_figure:
		if selected_figure:
			selected_figure.set_selected(false)
			
		selected_figure = clicked_figure
		selected_figure.set_selected(true)
		
		# FIX: Das UI zeigt nun die Werte der Figur an, egal ob Freund oder FEIND!
		if game_ui:
			game_ui.display_figure_stats(clicked_figure)
	
	# --- REICHWEITEN-INDIKATOREN FILTERN ---
	# Blaue (Bewegung) und gelbe (Angriff) Felder werden NUR für eigene Einheiten generiert
	if ist_spieler_zug and clicked_figure.team == 1:
		show_indicators_for(selected_figure)
	else:
		# Wenn es ein Gegner ist, blenden wir alle Aktionsfelder aus (reine Lese-Ansicht)
		clear_indicators()

# 4. KLICK AUF EIN FELD (Verhindert das Bewegen gegnerischer Figuren)
func _on_tile_clicked(tile):
	if selected_figure == null: return

	# FIX: Wenn die aktuell ausgewählte Figur ein Gegner ist (team != 1), 
	# darf sich dieser niemals durch Klicks bewegen! Auswahl wird aufgehoben.
	if selected_figure.team != 1:
		deselect_everything()
		return

	var turn_manager = get_node_or_null("%TurnManager")
	if not turn_manager: return
	
	var ist_spieler_zug = (turn_manager.active_player == turn_manager.player_one)
	if not ist_spieler_zug: return

	var valid_moves = get_valid_moves(selected_figure)

	# --- BEWEGUNG AUSFÜHREN ---
	if tile.grid_position in valid_moves and not tile.occupied:
		if not selected_figure.has_moved_this_round:
			var cost = selected_figure.stats.class_data.elixir_cost_move if selected_figure.stats.class_data else 1
			
			if turn_manager.active_player.current_energy >= cost:
				selected_figure.move_to(tile)
				selected_figure.has_moved_this_round = true
				turn_manager.spend_energy(cost)
				
				# Die Figur bleibt aktiv, damit sie danach noch angreifen kann!
				show_indicators_for(selected_figure)
			else:
				print("Nicht genügend Elixier für Bewegung!")
		else:
			print("Diese Figur hat sich diese Runde bereits bewegt!")
	else:
		# Klick auf ein ungültiges oder blockiertes Feld hebt die Auswahl auf
		deselect_everything()
