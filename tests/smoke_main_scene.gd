extends SceneTree
## Instantiates the gameplay scene long enough to surface ready/process errors.

func _initialize() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		push_error("FAIL: Main.tscn did not load")
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	print("PASS: Main.tscn initialized")
	quit(0)
