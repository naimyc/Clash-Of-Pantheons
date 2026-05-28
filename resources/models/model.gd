extends Node3D
class_name CharacterModel

# --- INITIALISIERUNG ---
func _ready() -> void:
	# Wir nehmen das feste Laden aus _ready() heraus.
	# Der GridManager ruft 'apply_skin()' direkt nach dem Spawnen auf!
	pass

# --- SKIN ANWENDEN ---
# Diese Funktion akzeptiert jetzt sowohl einen Pfad (String) als auch ein direktes Bild (Texture2D)
func apply_skin(texture_data) -> void:
	var tex: Texture2D = null
	
	# Prüfen, ob ein Textpfad oder direkt ein Textur-Objekt übergeben wurde
	if texture_data is String:
		tex = load(texture_data) as Texture2D
	elif texture_data is Texture2D:
		tex = texture_data
		
	# Falls keine gültige Textur gefunden wurde, brechen wir ab (Sicherheit)
	if tex == null:
		print("Fehler: Keine gültige Textur für das Minecraft-Modell übergeben!")
		return

	# Sucht nach dem Skelett-Knoten im Modell
	var skeleton_node = get_node_or_null("Skeleton/Skeleton3D")
	if skeleton_node:
		apply_materials(skeleton_node, tex)
	else:
		# Fallback: Falls die Struktur anders ist, durchsuchen wir das gesamte Modell
		apply_materials(self, tex)


# --- REKURSIVE MATERIAL-ANWENDUNG (MINECRAFT-STYLE) ---
# Durchsucht alle Kindknoten, erstellt eigene Material-Instanzen und setzt die Textur scharf (PixelArt)
func apply_materials(node: Node, tex: Texture2D):
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh = child.mesh
			if mesh == null:
				continue

			# Existierendes Material duplizieren, um Textur-Fehler zwischen den Figuren zu vermeiden
			var mat = child.get_surface_override_material(0)
			if not mat and mesh.surface_get_material(0):
				mat = mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			elif not mat:
				mat = StandardMaterial3D.new()
			else:
				mat = mat.duplicate() as StandardMaterial3D

			# Pixel-Art / Minecraft Textureinstellungen anwenden
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Verhindert, dass Pixel verschwimmen
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED       # Minecraft-typischer flacher Look

			# Dem Mesh das neue, einzigartige Oberflächen-Material zuweisen
			child.set_surface_override_material(0, mat)

		# Rekursiver Aufruf für tiefer verschachtelte Knochen/Meshes
		apply_materials(child, tex)
