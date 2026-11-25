extends SceneTree
## Renders a labelled gallery of Kenney models with axis markers (red = +X, blue = -Z),
## so orientation and scale can be checked by eye. Needs a real renderer (xvfb + opengl3):
##   godot --path . --rendering-driver opengl3 -s res://tests/asset_gallery.gd -- --set=roads --out=/tmp/g.png

var _frames := 0
var _out := ""


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_out = str(args.get("out", "user://gallery.png"))
	var set_name := str(args.get("set", "roads"))
	var items: Array = []
	var top := true
	match set_name:
		"roads":
			items = ["roads/road-straight", "roads/road-crossing", "roads/road-intersection", "roads/road-crossroad", "roads/road-square", "roads/light-square", "roads/traffic-light", "roads/construction-barrier"]
		"city":
			items = ["city/building-a", "city/building-d", "city/building-h", "city/building-k", "city/building-skyscraper-a", "city/building-skyscraper-c", "city/detail-awning-wide", "city/detail-parasol-a"]
			top = false
		"suburban":
			items = ["suburban/building-type-a", "suburban/building-type-k", "suburban/building-type-t", "suburban/tree-large", "suburban/tree-small", "suburban/planter", "suburban/fence-low", "suburban/driveway-short"]
			top = false
		"cars":
			items = ["cars/sedan-sports", "cars/hatchback-sports", "cars/race", "cars/police", "cars/taxi", "cars/suv", "cars/van", "cars/truck"]
			top = false
	var root3d := Node3D.new()
	root.add_child(root3d)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	root3d.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6d8a5a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	we.environment = env
	root3d.add_child(we)
	for i in items.size():
		var scene := load("res://game/art/kenney/%s.glb" % items[i]) as PackedScene
		var inst := scene.instantiate() as Node3D
		var x := float(i % 4) * 2.0
		var z := float(i / 4) * 2.4
		inst.position = Vector3(x, 0, z)
		root3d.add_child(inst)
		var red := MeshInstance3D.new()
		red.mesh = BoxMesh.new()
		red.scale = Vector3(0.12, 0.05, 0.12)
		red.position = Vector3(x + 0.62, 0.05, z)
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color.RED
		red.material_override = rm
		root3d.add_child(red)
		var blue := MeshInstance3D.new()
		blue.mesh = BoxMesh.new()
		blue.scale = Vector3(0.12, 0.05, 0.12)
		blue.position = Vector3(x, 0.05, z - 0.62)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color.BLUE
		blue.material_override = bm
		root3d.add_child(blue)
		var label := Label3D.new()
		label.text = str(items[i]).get_file()
		label.font_size = 28
		label.pixel_size = 0.004
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = Vector3(x, 0.1, z + 0.8)
		root3d.add_child(label)
	var cam := Camera3D.new()
	if top:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 5.5
		cam.position = Vector3(3, 10, 1.4)
		cam.rotation_degrees = Vector3(-90, 0, 0)
	else:
		cam.position = Vector3(3, 3.2, 7.5)
		cam.rotation_degrees = Vector3(-22, 0, 0)
		cam.fov = 50
	root3d.add_child(cam)
	cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out)
		print("gallery saved ", _out)
		quit()
	return false
