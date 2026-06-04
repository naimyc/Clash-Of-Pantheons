extends WorldEnvironment

func _ready():
	var env = Environment.new()

	# Sky — cold moonlit midnight, deep navy to icy silver horizon
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.02, 0.03, 0.08)
	sky_mat.sky_horizon_color    = Color(0.12, 0.18, 0.32)
	sky_mat.ground_horizon_color = Color(0.06, 0.08, 0.16)
	sky_mat.ground_bottom_color  = Color(0.01, 0.01, 0.03)
	sky_mat.energy_multiplier    = 1.1

	var sky = Sky.new()
	sky.sky_material             = sky_mat
	env.sky                      = sky
	env.background_mode          = Environment.BG_SKY
	env.background_energy_multiplier = 0.85

	# Ambient — cold blue-silver moonlight, soft enough to read pieces clearly
	env.ambient_light_source  = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color   = Color(0.20, 0.28, 0.50)
	env.ambient_light_energy  = 1.1

	# Filmic — preserves marble whites without blowing out
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white    = 3.0

	# Glow — cool ice-blue bloom, restrained
	env.glow_enabled       = true
	env.glow_normalized    = true
	env.glow_intensity     = 0.5
	env.glow_bloom         = 0.10
	env.glow_blend_mode    = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.2
	env.set_glow_level(1, 0.1)
	env.set_glow_level(2, 0.1)
	env.set_glow_level(3, 0.1)

	# Fog — thin cold mist, barely there, just softens the far edge
	env.fog_enabled            = true
	env.fog_light_color        = Color(0.15, 0.20, 0.40)
	env.fog_light_energy       = 0.4
	env.fog_density            = 0.004
	env.fog_aerial_perspective = 0.3

	# SSAO — crisp marble contact shadows
	env.ssao_enabled   = true
	env.ssao_radius    = 0.8
	env.ssao_intensity = 1.4
	env.ssao_power     = 1.6

	# Slight contrast boost — makes the black/white board pop
	env.adjustment_enabled    = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast   = 1.1
	env.adjustment_saturation = 0.8   # slightly desaturated — elegant, not cartoon

	environment = env
