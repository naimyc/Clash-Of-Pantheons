extends Node
# Add to Project → Autoload as "DebugNetwork"
# Only active when OS.has_feature("debug") — stripped in release builds

const PORT = 7070
const HOST_IP = "127.0.0.1"

# Set in Project Settings → Run → Main Run Args (per instance):
#   Instance 1: --host
#   Instance 2: --join
# Without args, uses auto-detect (recommended for editor testing with two instances)

func _ready():
	if not OS.is_debug_build(): return

	var args = OS.get_cmdline_args()

	if "--host" in args:
		_start_host()
	elif "--join" in args:
		_start_client()
	else:
		_auto_detect()

func _auto_detect():
	# ROOT CAUSE FIX 1:
	# The old logic waited 0.3s then checked if peer==null — but BOTH windows do this,
	# so both see null and both call _start_host(). They never connect to each other.
	#
	# Fix: Use a lock file to determine roles without args.
	# First window to create the lock file is host; second window finds it and joins.
	var lock_path = OS.get_user_data_dir() + "/debug_host.lock"
	var lock_file = FileAccess.open(lock_path, FileAccess.READ)
	if lock_file == null:
		# Lock file doesn't exist — we are the first window, become host
		var write = FileAccess.open(lock_path, FileAccess.WRITE)
		if write:
			write.store_string("host")
			write.close()
		_start_host()
		# Clean up lock after a delay so next test run works correctly
		await get_tree().create_timer(5.0).timeout
		if FileAccess.file_exists(lock_path):
			DirAccess.remove_absolute(lock_path)
	else:
		lock_file.close()
		# Lock file exists — another window is already hosting, we join
		_start_client()

func _start_host():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 2)
	if err != OK:
		print("[DEBUG] Failed to create server on port ", PORT, " — error: ", err)
		return
	multiplayer.multiplayer_peer = peer
	print("[DEBUG] Hosting on port ", PORT, " — I am peer_id 1")

	# ROOT CAUSE FIX 2:
	# Old code changed scene inside peer_connected, which ran BEFORE TurnManager could
	# read the correct peer_id. Now we change scene immediately after the timer so
	# TurnManager._ready() runs with the network fully established.
	# peer_connected is connected BEFORE scene change so TurnManager can also connect it.
	multiplayer.peer_connected.connect(func(id):
		print("[DEBUG] Client connected: peer_id ", id)
		# Small settle delay, then load the game scene
		await get_tree().create_timer(0.2).timeout
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	)

func _start_client():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(HOST_IP, PORT)
	if err != OK:
		print("[DEBUG] Failed to create client — error: ", err)
		return
	multiplayer.multiplayer_peer = peer
	print("[DEBUG] Joining ", HOST_IP, ":", PORT)

	multiplayer.connected_to_server.connect(func():
		print("[DEBUG] Connected! My peer_id = ", multiplayer.get_unique_id())
		# ROOT CAUSE FIX 3:
		# Give ENet one extra frame to fully stabilise the unique_id before
		# TurnManager._ready() reads it. Without this, get_unique_id() can still
		# return 1 (the default) on the client side for one frame.
		await get_tree().process_frame
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	)

	multiplayer.connection_failed.connect(func():
		print("[DEBUG] Connection failed — is the host window running?")
	)
