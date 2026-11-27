extends Node3D
# Pizzeria vertical slice: tactile cooking, dynamic camera, illustrated recipe UI and packaging.
const WORDS = {
 "en": ["Pizzavito", "Stretch the dough", "Spread sauce, then add toppings", "Bake — stop in the green zone", "Swipe across the pizza to slice", "Start recipe", "Next recipe", "Kitchen", "Sauce", "Tomato", "Mushroom", "Cheese", "Pepper", "Bake", "Stop", "Recipe complete!", "Free toppings", "Recipe", "Reset", "Undo", "Italian", "Woodland", "Drag from the centre outwards", "Choose a topping and touch the pizza", "Swipe from one edge to the other"],
 "ar": ["بيتزافيتو", "افرد العجين", "وزّع الصلصة ثم أضف المكونات", "اخبز البيتزا وتوقف عند المنطقة الخضراء", "اسحب عبر البيتزا لتقطيعها", "ابدأ الوصفة", "الوصفة التالية", "المطبخ", "صلصة", "طماطم", "فطر", "جبنة", "فلفل", "اخبز", "أوقف", "اكتملت الوصفة!", "مكونات حرة", "وصفة", "إعادة", "تراجع", "إيطالي", "ريفي", "اسحب من المركز نحو الخارج", "اختر المكون والمس البيتزا", "اسحب من حافة إلى أخرى"],
 "pt": ["Pizzavito", "Abra a massa", "Espalhe o molho e adicione ingredientes", "Asse — pare na zona verde", "Deslize pela pizza para cortar", "Iniciar receita", "Próxima receita", "Cozinha", "Molho", "Tomate", "Cogumelo", "Queijo", "Pimentão", "Assar", "Parar", "Receita concluída!", "Ingredientes livres", "Receita", "Reiniciar", "Desfazer", "Italiana", "Rústica", "Arraste do centro para fora", "Escolha um ingrediente e toque na pizza", "Deslize de uma borda à outra"]
}
const RECIPES = [
 ["tomato","cheese"], ["mushroom","cheese"], ["pepper","tomato"], ["cheese","pepper"], ["tomato","mushroom"],
 ["pepper","cheese","tomato"], ["mushroom","pepper"], ["cheese","mushroom","tomato"], ["tomato","pepper","mushroom"], ["tomato","mushroom","cheese","pepper"]
]
const KINDS = ["sauce","tomato","mushroom","cheese","pepper"]
const COLORS = [Color("#b93828"),Color("#e6543b"),Color("#d9b79b"),Color("#ffe188"),Color("#66a947")]
var lang = "en"
var level = 0
var theme = 0
var phase = -1
var camera: Camera3D
var room: Node3D
var pizza: Node3D
var dough: MeshInstance3D
var sauce: MeshInstance3D
var topping_root: Node3D
var cuts: Node3D
var hud: Control
var title_label: Label
var detail: Label
var actions: HBoxContainer
var meter: ProgressBar
var tally: Label
var selected = "sauce"
var stretch = 0.0
var sauce_amount = 0
var baking = false
var heat = 0.0
var sliced = 0
var dragging = false
var last_world = Vector3.ZERO
var drag_start = Vector3.ZERO
var travelled = 0.0
var placed: Array[String] = []
var manifest: Dictionary = {}
var materials: Dictionary = {}
var crust: MeshInstance3D
var rolling: Node3D
var sauce_marks: Node3D
var package_box: Node3D
var oven_station: Node3D
var oven_glow: OmniLight3D
var stage_label: Label
var menu_panel: PanelContainer
var menu_title: Label
var menu_body: Label
var ingredient_buttons: HBoxContainer
var camera_goal = Vector3(0,7.6,8.5)
var camera_focus = Vector3(0,1.2,0.6)
var camera_zoom = 7.4
var cut_angles: Array[float] = []
var sound_player: AudioStreamPlayer
var sfx: AudioStreamWAV
var free_mode = false
var celebration: Node3D

func _ready() -> void:
 var cfg = ConfigFile.new()
 if cfg.load("user://progress.cfg") == OK:
  lang = str(cfg.get_value("game","lang","en"))
  if not WORDS.has(lang): lang = "en"
  level = clampi(int(cfg.get_value("game","level",0)),0,9)
  theme = clampi(int(cfg.get_value("game","theme",0)),0,1)
 if FileAccess.file_exists("res://assets/imported/manifest.json"):
  var decoded = JSON.parse_string(FileAccess.get_file_as_string("res://assets/imported/manifest.json"))
  if decoded is Dictionary: manifest = decoded
 var env = WorldEnvironment.new()
 var environment = Environment.new()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color("#75634f")
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color("#e8eef3")
 environment.ambient_light_energy = 0.32
 env.environment = environment
 add_child(env)
 var light = DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-48,-32,0)
 light.light_color = Color("#fff2e0")
 light.light_energy = 0.62
 light.shadow_enabled = true
 add_child(light)
 camera = Camera3D.new()
 camera.position = camera_goal
 add_child(camera)
 camera.look_at(camera_focus)
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = camera_zoom
 camera.current = true
 make_room()
 make_pizza()
 make_ui()
 setup_sound()
 refresh()
 if "--smoke-test" in OS.get_cmdline_user_args():
  for key in ["pizza","tomato","oven","counter"]:
   assert(manifest.has(key), "Missing external model "+key)
   assert(ResourceLoader.exists(manifest[key]["path"]), "Model failed import "+key)
  start_recipe()
  stretch = 1.0
  advance()
  assert(phase == 1)
  sauce_amount = 10
  for kind in RECIPES[level]:
   placed.append(kind)
   placed.append(kind)
  advance()
  assert(phase == 2)
  heat = 0.72
  advance()
  assert(phase == 3)
  sliced = 3
  advance()
  assert(phase == 4)
  pack_pizza()
  assert(phase == 5)
  print("PIZZAVITO_SMOKE_OK")
  get_tree().quit()

func t(i: int) -> String:
 return WORDS[lang][i]

func save_game() -> void:
 var cfg = ConfigFile.new()
 cfg.set_value("game","lang",lang)
 cfg.set_value("game","level",level)
 cfg.set_value("game","theme",theme)
 cfg.save("user://progress.cfg")

func mat(c: Color) -> StandardMaterial3D:
 var key = c.to_html()
 if materials.has(key): return materials[key]
 var m = StandardMaterial3D.new()
 m.albedo_color = c
 m.roughness = 0.82
 materials[key] = m
 return m

func mesh_node(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
 var n = MeshInstance3D.new()
 n.mesh = mesh
 n.material_override = mat(c)
 n.position = pos
 parent.add_child(n)
 return n

func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
 var m = BoxMesh.new()
 m.size = size
 return mesh_node(parent,m,c,pos)

func disc(parent: Node3D, radius: float, height: float, pos: Vector3, c: Color) -> MeshInstance3D:
 var m = CylinderMesh.new()
 m.top_radius = radius
 m.bottom_radius = radius
 m.height = height
 m.radial_segments = 64
 return mesh_node(parent,m,c,pos)

func model_bounds(node: Node3D) -> AABB:
 var found = false
 var bounds = AABB()
 for child in node.find_children("*","MeshInstance3D",true,false):
  var mesh = child as MeshInstance3D
  if mesh.mesh == null: continue
  var b = node.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
  bounds = bounds.merge(b) if found else b
  found = true
 return bounds

func asset(parent: Node3D, key: String, pos: Vector3, size: float) -> bool:
 if not manifest.has(key): return false
 var resource = load(manifest[key]["path"])
 if not resource is PackedScene: return false
 var pivot = Node3D.new()
 parent.add_child(pivot)
 var item = resource.instantiate()
 if not item is Node3D:
  item.free()
  pivot.queue_free()
  return false
 pivot.add_child(item)
 var b = model_bounds(pivot)
 var largest = maxf(b.size.x,maxf(b.size.y,b.size.z))
 if largest < 0.0001:
  pivot.queue_free()
  return false
 item.position -= b.get_center()
 pivot.scale = Vector3.ONE * (size/largest)
 pivot.position = pos
 return true

func make_room() -> void:
 if is_instance_valid(room): room.queue_free()
 room = Node3D.new()
 add_child(room)
 var wall = Color("#d9b58a") if theme == 0 else Color("#658578")
 var counter_colour = Color("#8a4b31") if theme == 0 else Color("#694837")
 box(room,Vector3(18,0.16,14),Vector3(0,-0.15,0),Color("#94765b"))
 for x in range(-6,7):
  for z in range(-5,6):
   box(room,Vector3(1.0,0.025,1.0),Vector3(x,-0.05,z),Color("#b6a78e") if (x+z)%2==0 else Color("#806d58"))
 box(room,Vector3(15,5,0.22),Vector3(0,2.4,-4.3),wall)
 box(room,Vector3(0.25,5,8),Vector3(-7.1,2.4,-0.3),wall)
 for x in [-4.9,-2.5,2.5,4.9]:
  box(room,Vector3(1.65,1.25,0.7),Vector3(x,3.0,-3.8),counter_colour)
  box(room,Vector3(1.35,0.08,0.09),Vector3(x,2.75,-3.42),Color("#f9e4ae"))
 box(room,Vector3(3.4,1.85,0.15),Vector3(0,3.0,-4.12),Color("#d4f1ef"))
 box(room,Vector3(0.09,1.85,0.19),Vector3(0,3.0,-4.0),Color("#fff0cd"))
 box(room,Vector3(3.4,0.08,0.19),Vector3(0,3.0,-4.0),Color("#fff0cd"))
 box(room,Vector3(8.7,1.15,3.7),Vector3(0,0.52,0.6),counter_colour)
 box(room,Vector3(9.0,0.20,3.9),Vector3(0,1.18,0.6),Color("#cfad7b"))
 for x in range(-4,5):
  box(room,Vector3(0.025,0.012,3.72),Vector3(x,1.285,0.6),Color("#a77b52"))
 for x in [-3.5,-1.2,1.2,3.5]:
  box(room,Vector3(1.75,0.76,0.13),Vector3(x,0.62,2.49),counter_colour.darkened(0.16))
  box(room,Vector3(0.55,0.09,0.11),Vector3(x,0.86,2.59),Color("#ddbb75"))
 asset(room,"counter",Vector3(-3.5,0.8,-2.8),2.4)
 asset(room,"oven",Vector3(3.7,1.1,-2.8),2.3)
 asset(room,"hood",Vector3(3.7,3.3,-3.65),1.7)
 asset(room,"cabinet",Vector3(-3.5,2.9,-3.75),1.3)
 asset(room,"dishrack",Vector3(-5.0,1.65,-2.8),0.9)
 asset(room,"shelf",Vector3(-5.9,3.1,-3.7),1.2)
 asset(room,"jar",Vector3(-2.0,1.55,-2.8),0.42)
 asset(room,"jar_b",Vector3(-1.55,1.48,-2.8),0.34)
 asset(room,"pot",Vector3(2.5,1.65,-2.8),0.75)
 asset(room,"menu",Vector3(1.5,2.6,-3.7),0.82)
 asset(room,"fridge",Vector3(6.0,1.45,-2.7),2.9)
 asset(room,"sink",Vector3(-5.7,0.9,-2.7),2.0)
 asset(room,"plate",Vector3(-3.4,1.35,1.5),0.9)
 asset(room,"bowl",Vector3(3.4,1.52,1.45),1.0)
 asset(room,"pizza",Vector3(-3.35,1.53,-0.4),1.3)
 asset(room,"board",Vector3(-3.15,1.33,0.8),1.3)
 asset(room,"knife",Vector3(-3.0,1.45,0.8),0.8)
 asset(room,"crate_tomato",Vector3(4.9,0.5,1.8),1.0)
 asset(room,"crate_cheese",Vector3(-4.9,0.5,1.8),1.0)
 for i in range(4):
  var x = -2.65 + i*1.78
  disc(room,0.56,0.10,Vector3(x,1.35,-0.94),Color("#7d9385"))
  disc(room,0.48,0.04,Vector3(x,1.42,-0.94),Color("#dcd0b3"))
  asset(room,KINDS[i+1],Vector3(x,1.62,-0.94),0.57)
 asset(room,"tomato",Vector3(3.25,1.5,-0.35),0.65)
 asset(room,"mushroom",Vector3(3.8,1.5,-0.1),0.6)
 for x in [-5.9,5.9]:
  disc(room,0.29,0.55,Vector3(x,1.2,1.7),Color("#bd6648"))
  for j in range(5):
   var leaf = SphereMesh.new()
   leaf.radius = 0.24
   leaf.height = 0.65
   var n = mesh_node(room,leaf,Color("#4e945c"),Vector3(x+cos(j*1.26)*0.21,1.72,1.7+sin(j*1.26)*0.21))
   n.rotation.z = cos(j*1.26)*0.55
 if theme == 0:
  for i in range(8):
   box(room,Vector3(0.78,0.65,0.07),Vector3(-3.1+i*0.88,1.93,-4.15),Color("#ad694c") if i%2==0 else Color("#d2af84"))
 else:
  for i in range(9):
   box(room,Vector3(0.045,4.6,0.1),Vector3(-6.4+i*1.6,2.2,-4.14),Color("#805f48"))

func make_pizza() -> void:
 if is_instance_valid(pizza): pizza.queue_free()
 pizza = Node3D.new()
 pizza.position = Vector3(0,1.38,0.55)
 add_child(pizza)
 disc(pizza,1.93,0.12,Vector3(0,-0.04,0),Color("#a36b3d"))
 dough = disc(pizza,1.62,0.23,Vector3(0,0.13,0),Color("#e5bd79"))
 var rim = TorusMesh.new()
 rim.inner_radius = 1.29
 rim.outer_radius = 1.65
 rim.rings = 48
 rim.ring_segments = 12
 crust = mesh_node(pizza,rim,Color("#c99451"),Vector3(0,0.22,0))
 sauce_marks = Node3D.new()
 pizza.add_child(sauce_marks)
 rolling = Node3D.new()
 pizza.add_child(rolling)
 rolling.position = Vector3(0,0.52,0.0)
 if not asset(rolling,"rolling_pin",Vector3.ZERO,1.8):
  var roller = disc(rolling,0.20,1.65,Vector3.ZERO,Color("#bc834a"))
  roller.rotation.z = PI/2
  for x in [-0.99,0.99]:
   var handle = disc(rolling,0.09,0.40,Vector3(x,0,0),Color("#774f35"))
   handle.rotation.z = PI/2
 rolling.visible = false
 sauce = disc(pizza,1.42,0.04,Vector3(0,0.265,0),COLORS[0])
 sauce.visible = false
 topping_root = Node3D.new()
 pizza.add_child(topping_root)
 cuts = Node3D.new()
 pizza.add_child(cuts)
 cut_angles.clear()
 if is_instance_valid(package_box): package_box.queue_free()
 if is_instance_valid(oven_station): oven_station.queue_free()
 if is_instance_valid(celebration): celebration.queue_free()

func make_ui() -> void:
 var layer = CanvasLayer.new()
 add_child(layer)
 hud = Control.new()
 layer.add_child(hud)
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var top = PanelContainer.new()
 top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 top.offset_bottom = 76
 top.offset_left = 18
 top.offset_right = -18
 top.offset_top = 12
 top.mouse_filter = Control.MOUSE_FILTER_IGNORE
 style_panel(top,Color("#123d39"))
 hud.add_child(top)
 var bar = HBoxContainer.new()
 bar.add_theme_constant_override("separation",16)
 top.add_child(bar)
 title_label = Label.new()
 title_label.add_theme_font_size_override("font_size",34)
 title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 bar.add_child(title_label)
 for language in ["en","ar","pt"]:
  var b = make_button(language.to_upper(),func(): set_language(language))
  bar.add_child(b)
 bar.add_child(make_button("↻",reset_recipe))
 detail = Label.new()
 detail.position = Vector2(20,91)
 detail.size = Vector2(1240,42)
 detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 detail.add_theme_font_size_override("font_size",32)
 detail.add_theme_color_override("font_color",Color("#173b35"))
 detail.add_theme_color_override("font_outline_color",Color("#fff3dd"))
 detail.add_theme_constant_override("outline_size",7)
 hud.add_child(detail)
 tally = Label.new()
 tally.position = Vector2(20,138)
 tally.size = Vector2(1240,35)
 tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 tally.add_theme_font_size_override("font_size",25)
 tally.add_theme_color_override("font_color",Color("#173b35"))
 tally.add_theme_color_override("font_outline_color",Color("#fff3dd"))
 tally.add_theme_constant_override("outline_size",6)
 hud.add_child(tally)
 meter = ProgressBar.new()
 meter.position = Vector2(440,177)
 meter.size = Vector2(400,22)
 meter.max_value = 100
 meter.show_percentage = false
 var track = StyleBoxFlat.new()
 track.bg_color = Color("#49382c")
 track.set_corner_radius_all(11)
 meter.add_theme_stylebox_override("background",track)
 var fill = StyleBoxFlat.new()
 fill.bg_color = Color("#80c46c")
 fill.set_corner_radius_all(11)
 meter.add_theme_stylebox_override("fill",fill)
 hud.add_child(meter)
 stage_label = Label.new()
 stage_label.position = Vector2(20,205)
 stage_label.size = Vector2(1240,32)
 stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 stage_label.add_theme_font_size_override("font_size",23)
 stage_label.add_theme_color_override("font_outline_color",Color("#35271b"))
 stage_label.add_theme_constant_override("outline_size",5)
 stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hud.add_child(stage_label)
 menu_panel = PanelContainer.new()
 menu_panel.position = Vector2(45,235)
 menu_panel.size = Vector2(330,280)
 style_panel(menu_panel,Color("#214c46"))
 hud.add_child(menu_panel)
 var menu_stack = VBoxContainer.new()
 menu_stack.add_theme_constant_override("separation",18)
 menu_panel.add_child(menu_stack)
 menu_title = Label.new()
 menu_title.add_theme_font_size_override("font_size",42)
 menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 menu_stack.add_child(menu_title)
 menu_body = Label.new()
 menu_body.add_theme_font_size_override("font_size",24)
 menu_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 menu_stack.add_child(menu_body)
 var bottom = PanelContainer.new()
 bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 bottom.offset_top = -112
 bottom.offset_left = 18
 bottom.offset_right = -18
 bottom.offset_bottom = -10
 style_panel(bottom,Color("#123d39"))
 hud.add_child(bottom)
 actions = HBoxContainer.new()
 actions.alignment = BoxContainer.ALIGNMENT_CENTER
 actions.add_theme_constant_override("separation",10)
 bottom.add_child(actions)

func style_panel(p: PanelContainer,c: Color) -> void:
 var s = StyleBoxFlat.new()
 s.bg_color = c
 s.set_corner_radius_all(22)
 s.set_border_width_all(3)
 s.border_color = Color("#d6ad68")
 s.shadow_color = Color(0.08,0.04,0.02,0.5)
 s.shadow_size = 5
 s.content_margin_left = 16
 s.content_margin_right = 16
 s.content_margin_top = 10
 s.content_margin_bottom = 10
 p.add_theme_stylebox_override("panel",s)

func make_button(label: String, action: Callable) -> Button:
 var b = Button.new()
 b.text = label
 b.custom_minimum_size = Vector2(94,68)
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.add_theme_font_size_override("font_size",24)
 for state in ["normal","hover","pressed","disabled"]:
  var s = StyleBoxFlat.new()
  s.bg_color = Color("#b64d30") if state=="normal" else Color("#d48d42")
  s.set_border_width_all(2)
  s.border_color = Color("#f0c888")
  s.shadow_size = 3
  s.shadow_color = Color(0.12,0.06,0.03,0.5)
  if state=="disabled": s.bg_color = Color("#566c63")
  s.set_corner_radius_all(16)
  s.content_margin_left = 14
  s.content_margin_right = 14
  b.add_theme_stylebox_override(state,s)
 b.pressed.connect(func():
  play_click()
  action.call())
 return b

func set_language(value: String) -> void:
 lang = value
 save_game()
 refresh()

func toggle_theme() -> void:
 theme = 1-theme
 make_room()
 save_game()
 refresh()

func reset_recipe() -> void:
 phase = -1
 baking = false
 dragging = false
 make_pizza()
 refresh()

func start_recipe() -> void:
 make_pizza()
 phase = 0
 stretch = 0.0
 sauce_amount = 0
 sliced = 0
 heat = 0.0
 baking = false
 selected = "sauce"
 placed.clear()
 dough.scale = Vector3(0.58,1.0,0.58)
 crust.scale = dough.scale
 rolling.visible = true
 refresh()

func next_recipe() -> void:
 level = (level+1)%RECIPES.size()
 save_game()
 start_recipe()

func requirements_met() -> bool:
 if sauce_amount < 8: return false
 if free_mode: return not placed.is_empty()
 for kind in RECIPES[level]:
  if placed.count(kind) < 2: return false
 return true

func add_action(label: String, action: Callable, enabled: bool = true) -> void:
 var b = make_button(label,action)
 b.disabled = not enabled
 actions.add_child(b)

func refresh() -> void:
 if not is_instance_valid(actions): return
 hud.layout_direction = Control.LAYOUT_DIRECTION_RTL if lang == "ar" else Control.LAYOUT_DIRECTION_LTR
 for c in actions.get_children():
  actions.remove_child(c)
  c.queue_free()
 title_label.text = t(0)+"  ·  "+t(17)+" "+str(level+1)+"/10"
 menu_panel.visible = phase == -1
 menu_title.text = localise("Pizza studio","استوديو البيتزا","Estúdio de pizza")
 menu_body.text = localise("Make your own pizza! 10 recipes • 2 kitchens • 5 cooking steps","اصنع بيتزتك! ١٠ وصفات • مطبخان • ٥ خطوات","Crie sua pizza! 10 receitas • 2 cozinhas • 5 etapas")
 stage_label.text = "" if phase < 0 else "   ".join([("●" if i<=phase else "○")+" "+str(i+1) for i in range(5)])
 set_camera_for_phase()
 detail.text = t(7)+": "+t(20+theme)
 tally.text = ""
 meter.visible = phase >= 0 and phase <= 3
 if phase == -1:
  add_action(t(5),start_guided)
  add_action(t(16),start_free)
  add_action(t(7)+": "+t(20+theme),toggle_theme)
 elif phase == 0:
  detail.text = t(1)
  tally.text = t(22)
  meter.value = stretch*100
  add_action(localise("Next","التالي","Avançar")+" ✓",advance,stretch>=0.99)
 elif phase == 1:
  detail.text = t(2)
  var names: Array[String] = []
  for kind in RECIPES[level]:
   names.append(t(8+KINDS.find(kind))+" "+str(mini(placed.count(kind),2))+"/2")
  tally.text = " • ".join(names)
  meter.value = minf(100,(sauce_amount/8.0)*50+placed.size()*50.0/(RECIPES[level].size()*2))
  for i in range(KINDS.size()):
   var kind = KINDS[i]
   add_action(("● " if selected==kind else "")+t(8+i),func(): choose(kind))
  add_action(t(19),undo,not placed.is_empty())
  add_action("✓",advance,requirements_met())
 elif phase == 2:
  detail.text = t(3)
  tally.text = localise("Bake to 60–85% • golden crust","اخبز حتى ٦٠–٨٥٪ • حواف ذهبية","Asse até 60–85% • borda dourada")
  meter.value = heat*100
  add_action(t(13),begin_baking,not baking)
  add_action(t(14),stop_baking,baking)
  add_action("✓",advance,not baking and heat>=0.60 and heat<=0.85)
 elif phase == 3:
  detail.text = t(4)
  tally.text = t(24)+"  "+str(sliced)+"/3"
  meter.value = sliced*100.0/3
  add_action("✓",advance,sliced>=3)
 elif phase == 4:
  detail.text = localise("Pack your pizza!","غلّف بيتزتك!","Embale sua pizza!")
  tally.text = localise("Tap the box to close it","اضغط على العلبة لإغلاقها","Toque na caixa para fechar")
  add_action(localise("Pack","تغليف","Embalar"),pack_pizza)
 elif phase == 5:
  detail.text = t(15)+"  ★★★"
  add_action(t(6),next_recipe)
  add_action(t(7),toggle_theme)
  add_action(localise("Home","الرئيسية","Início"),reset_recipe)

func choose(kind: String) -> void:
 selected = kind
 refresh()

func undo() -> void:
 if placed.is_empty(): return
 placed.pop_back()
 var children = topping_root.get_children()
 if not children.is_empty():
  var n = children.back()
  topping_root.remove_child(n)
  n.queue_free()
 refresh()

func begin_baking() -> void:
 heat = 0
 baking = true
 refresh()

func stop_baking() -> void:
 baking = false
 refresh()

func advance() -> void:
 if phase == 0 and stretch>=0.99:
  phase = 1
  rolling.visible = false
 elif phase == 1 and requirements_met():
  phase = 2
  make_oven_station()
 elif phase == 2 and not baking and heat>=0.60 and heat<=0.85:
  phase = 3
  if is_instance_valid(oven_station): oven_station.visible = false
 elif phase == 3 and sliced>=3:
  phase = 4
  make_package()
  save_game()
 refresh()

func _process(delta: float) -> void:
 camera.position = camera.position.lerp(camera_goal, minf(delta*5,1))
 camera.look_at(camera_focus)
 camera.size = lerpf(camera.size,camera_zoom,minf(delta*5,1))
 if is_instance_valid(celebration):
  celebration.rotate_y(delta*0.4)
  for child in celebration.get_children():
   child.position.y += delta*0.35
   if child.position.y>2.0: child.position.y = 0.1
 if baking:
  heat = minf(1.0,heat+delta*0.17)
  meter.value = heat*100
  dough.material_override = mat(Color("#e5bd79").lerp(Color("#ad6932"),heat))
  crust.material_override = mat(Color("#c99451").lerp(Color("#a95a25"),heat))
  if is_instance_valid(oven_glow): oven_glow.light_energy = 0.3+heat*1.0
  if heat>=1.0:
   baking = false
   refresh()

func point_on_pizza(screen: Vector2) -> Vector3:
 var origin = camera.project_ray_origin(screen)
 var direction = camera.project_ray_normal(screen)
 var hit = Plane(Vector3.UP,1.66).intersects_ray(origin,direction)
 if hit == null: return Vector3(99,99,99)
 var local = pizza.to_local(hit)
 local.y = 0
 return local

func _unhandled_input(event: InputEvent) -> void:
 if phase == 4 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  if point_on_pizza(event.position).length()<2.15: pack_pizza()
  return
 if phase < 0 or phase > 3 or phase == 2: return
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  var p = point_on_pizza(event.position)
  if event.pressed and p.length() <= 1.75:
   dragging = true
   last_world = p
   drag_start = p
   travelled = 0
   if phase==1 and selected!="sauce": place_topping(p)
   elif phase==1 and selected=="sauce": paint_sauce(p)
  elif not event.pressed and dragging:
   if phase==3 and travelled>1.3 and sliced<3:
    cut_line(drag_start,p)
   dragging = false
 elif event is InputEventMouseMotion and dragging:
  var p = point_on_pizza(event.position)
  if p.length() > 1.95: return
  var distance = p.distance_to(last_world)
  if distance < 0.04: return
  travelled += distance
  if phase==0:
   stretch = minf(1.0,stretch+distance*0.19)
   dough.scale = Vector3(0.58+0.42*stretch,1,0.58+0.42*stretch)
   crust.scale = dough.scale
   rolling.position = Vector3(clampf(p.x,-1.0,1.0),0.52,clampf(p.z,-1.15,1.15))
   rolling.rotation.x += distance*2
   if stretch>=0.99: refresh()
   else: meter.value = stretch*100
  elif phase==1 and selected=="sauce":
   paint_sauce(p)
  elif phase==1 and selected!="sauce" and distance>0.20:
   place_topping(p)
  last_world = p

func place_topping(p: Vector3) -> void:
 if p.length()>1.38 or placed.size()>=40: return
 var kind = selected
 var pos = Vector3(p.x,0.32,p.z)
 var model_key = "tomato_slice" if kind=="tomato" and manifest.has("tomato_slice") else ("cheese_slice" if kind=="cheese" and manifest.has("cheese_slice") else kind)
 if not asset(topping_root,model_key,pos,0.39):
  disc(topping_root,0.12,0.07,pos,COLORS[KINDS.find(kind)])
 placed.append(kind)
 play_click()
 refresh()

func cut_line(a: Vector3,b: Vector3) -> void:
 var axis = (b-a).normalized()
 if axis.length()<0.01: return
 var angle = fposmod(atan2(axis.x,axis.z),PI)
 for prior in cut_angles:
  var diff = absf(angle-prior)
  if minf(diff,PI-diff)<0.32: return
 cut_angles.append(angle)
 var cut = box(cuts,Vector3(0.044,0.035,3.16),Vector3(0,0.48,0),Color("#754021"))
 cut.rotation.y = angle
 play_click()
 sliced += 1
 refresh()

func localise(en: String, ar: String, pt: String) -> String:
 return ar if lang=="ar" else (pt if lang=="pt" else en)

func start_guided() -> void:
 free_mode = false
 start_recipe()

func start_free() -> void:
 free_mode = true
 start_recipe()

func set_camera_for_phase() -> void:
 camera_focus = Vector3(0,1.5,0.55)
 if phase == -1:
  camera_goal = Vector3(0,6.9,9.2)
  camera_zoom = 7.6
  camera_focus = Vector3(-0.4,1.6,0.2)
 elif phase == 2:
  camera_goal = Vector3(0,6.0,8.8)
  camera_zoom = 5.8
 elif phase == 4 or phase == 5:
  camera_goal = Vector3(0,8.9,7.3)
  camera_zoom = 5.4
 else:
  camera_goal = Vector3(0,9.5,7.4)
  camera_zoom = 5.3

func paint_sauce(p: Vector3) -> void:
 if p.length()>1.27: return
 if sauce_marks.get_child_count() >= 48: return
 for mark in sauce_marks.get_children():
  if Vector2(mark.position.x-p.x,mark.position.z-p.z).length()<0.24: return
 disc(sauce_marks,0.32,0.036,Vector3(p.x,0.267,p.z),Color("#b73c29"))
 sauce_amount = mini(12,sauce_amount+1)
 if sauce_amount>=8:
  sauce.visible = true
  sauce.scale = Vector3(1,1,1)
  refresh()
 else:
  meter.value = sauce_amount/8.0*50

func make_oven_station() -> void:
 if is_instance_valid(oven_station): oven_station.queue_free()
 oven_station = Node3D.new()
 add_child(oven_station)
 oven_station.position = Vector3(0,1.3,-1.05)
 # Open stone oven surround, showing the actual pizza on the work surface.
 box(oven_station,Vector3(3.95,0.17,3.1),Vector3(0,0.01,0.9),Color("#544439"))
 for side in [-1,1]:
  box(oven_station,Vector3(0.34,1.22,1.55),Vector3(side*1.96,0.71,-0.03),Color("#b9724d"))
  for i in range(3):
   box(oven_station,Vector3(0.36,0.035,1.57),Vector3(side*1.96,0.30+i*0.34,-0.03),Color("#e2bb8d"))
 box(oven_station,Vector3(4.20,1.30,0.23),Vector3(0,0.73,-0.82),Color("#784d38"))
 box(oven_station,Vector3(4.30,0.22,1.24),Vector3(0,1.38,-0.25),Color("#af6748"))
 oven_glow = OmniLight3D.new()
 oven_glow.position = Vector3(0,1.05,0.20)
 oven_glow.light_color = Color("#ffa34d")
 oven_glow.light_energy = 0.35
 oven_glow.omni_range = 3.2
 oven_station.add_child(oven_glow)

func make_package() -> void:
 if is_instance_valid(package_box): package_box.queue_free()
 package_box = Node3D.new()
 pizza.add_child(package_box)
 box(package_box,Vector3(4.0,0.10,4.0),Vector3(0,-0.13,0),Color("#b88c54"))
 for side in [-1,1]:
  box(package_box,Vector3(0.08,0.32,4.0),Vector3(side*1.98,0.07,0),Color("#d4ab76"))
  box(package_box,Vector3(4.0,0.32,0.08),Vector3(0,0.07,side*1.98),Color("#d4ab76"))
 var lid = Node3D.new()
 lid.name = "Lid"
 package_box.add_child(lid)
 lid.position = Vector3(0,0.30,-1.98)
 box(lid,Vector3(4.0,0.09,4.0),Vector3(0,0,-2.0),Color("#d6ac77"))
 box(lid,Vector3(3.85,0.035,0.26),Vector3(0,0.065,-0.30),Color("#a34e36"))
 lid.rotation.x = -1.24

func pack_pizza() -> void:
 if phase!=4: return
 phase = 5
 if is_instance_valid(package_box):
  var lid = package_box.get_node("Lid") as Node3D
  var tween = create_tween()
  tween.tween_property(lid,"rotation:x",-PI,0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 celebration = Node3D.new()
 add_child(celebration)
 celebration.position = pizza.position
 for i in range(24):
  var m = SphereMesh.new()
  m.radius = 0.045
  m.height = 0.09
  mesh_node(celebration,m,[Color("#e5b550"),Color("#76b984"),Color("#d27246")][i%3],Vector3(cos(i*2.4)*2.1,0.1+float(i%8)*0.22,sin(i*2.4)*2.1))
 play_click()
 save_game()
 refresh()

func setup_sound() -> void:
 sound_player = AudioStreamPlayer.new()
 sound_player.volume_db = -15
 add_child(sound_player)
 # Original short non-musical tactile noise, no downloaded or musical material.
 sfx = AudioStreamWAV.new()
 sfx.format = AudioStreamWAV.FORMAT_16_BITS
 sfx.mix_rate = 22050
 var data = PackedByteArray()
 data.resize(2200*2)
 var rng = RandomNumberGenerator.new()
 rng.seed = 78213
 for i in range(2200):
  var envelope = exp(-float(i)/290.0)
  var val = int(rng.randf_range(-1.0,1.0)*envelope*10000)
  data.encode_s16(i*2,val)
 sfx.data = data

func play_click() -> void:
 if is_instance_valid(sound_player) and sfx!=null:
  sound_player.stream = sfx
  sound_player.play()
