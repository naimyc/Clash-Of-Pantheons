extends Node3D

func _ready() -> void:
	apply_skin("res://resources/skins/4.png")

func apply_skin(texture_path: String):
	var tex = load(texture_path)
	apply_materials($Skeleton/Skeleton3D, tex)


func apply_materials(node: Node, tex: Texture):
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh = child.mesh
			if mesh == null:
				continue

			# Duplicate the existing material if there is one
			var mat = mesh.surface_get_material(0)
			if mat:
				mat = mat.duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()

			# Apply your texture but keep UV mapping
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

			# Set to the mesh surface
			child.set_surface_override_material(0, mat)

		# Recursive call
		apply_materials(child, tex)
