extends Node3D
# First playable vertical slice. A fixed camera and touch gestures on the worktop.
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
 environment.background_color = Color("#f4ddbd")
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color("#fff1df")
 environment.ambient_light_energy = 0.85
 env.environment = environment
 add_child(env)
 var light = DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-55,-30,0)
 light.light_energy = 1.5
 light.shadow_enabled = true
 add_child(light)
 camera = Camera3D.new()
 camera.position = Vector3(0,8.6,7.8)
 add_child(camera)
 camera.look_at(Vector3(0,0.6,0))
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 10.6
 camera.current = true
 make_room()
 make_pizza()
 make_ui()
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
 var wall = Color("#f9dfb5") if theme == 0 else Color("#a6c2a4")
 var counter_colour = Color("#d68e55") if theme == 0 else Color("#9f704d")
 box(room,Vector3(18,0.16,14),Vector3(0,-0.15,0),Color("#d5bb97"))
 for x in range(-6,7):
  for z in range(-5,6):
   box(room,Vector3(1.0,0.025,1.0),Vector3(x,-0.05,z),Color("#eadac0") if (x+z)%2==0 else Color("#c4b69b"))
 box(room,Vector3(15,5,0.22),Vector3(0,2.4,-4.3),wall)
 box(room,Vector3(0.25,5,8),Vector3(-7.1,2.4,-0.3),wall)
 for x in [-4.9,-2.5,2.5,4.9]:
  box(room,Vector3(1.65,1.25,0.7),Vector3(x,3.0,-3.8),counter_colour)
  box(room,Vector3(1.35,0.08,0.09),Vector3(x,2.75,-3.42),Color("#f9e4ae"))
 box(room,Vector3(3.4,1.85,0.15),Vector3(0,3.0,-4.12),Color("#d4f1ef"))
 box(room,Vector3(0.09,1.85,0.19),Vector3(0,3.0,-4.0),Color("#fff0cd"))
 box(room,Vector3(3.4,0.08,0.19),Vector3(0,3.0,-4.0),Color("#fff0cd"))
 box(room,Vector3(8.7,1.15,3.7),Vector3(0,0.52,0.6),counter_colour)
 box(room,Vector3(9.0,0.20,3.9),Vector3(0,1.18,0.6),Color("#fff0d3"))
 asset(room,"counter",Vector3(-3.5,0.8,-2.8),2.4)
 asset(room,"oven",Vector3(3.7,1.1,-2.8),2.3)
 asset(room,"fridge",Vector3(6.0,1.45,-2.7),2.9)
 asset(room,"sink",Vector3(-5.7,0.9,-2.7),2.0)
 asset(room,"plate",Vector3(-3.4,1.35,1.5),0.9)
 asset(room,"bowl",Vector3(3.4,1.52,1.45),1.0)
 asset(room,"pizza",Vector3(-3.35,1.53,-0.4),1.3)
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

func make_pizza() -> void:
 if is_instance_valid(pizza): pizza.queue_free()
 pizza = Node3D.new()
 pizza.position = Vector3(0,1.38,0.55)
 add_child(pizza)
 disc(pizza,1.93,0.12,Vector3(0,-0.04,0),Color("#a36b3d"))
 dough = disc(pizza,1.62,0.23,Vector3(0,0.13,0),Color("#efd29b"))
 sauce = disc(pizza,1.42,0.04,Vector3(0,0.265,0),COLORS[0])
 sauce.visible = false
 topping_root = Node3D.new()
 pizza.add_child(topping_root)
 cuts = Node3D.new()
 pizza.add_child(cuts)

func make_ui() -> void:
 var layer = CanvasLayer.new()
 add_child(layer)
 hud = Control.new()
 layer.add_child(hud)
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var top = PanelContainer.new()
 top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 top.offset_bottom = 96
 top.mouse_filter = Control.MOUSE_FILTER_IGNORE
 style_panel(top,Color("#123d39"))
 hud.add_child(top)
 var bar = HBoxContainer.new()
 bar.add_theme_constant_override("separation",16)
 top.add_child(bar)
 title_label = Label.new()
 title_label.add_theme_font_size_override("font_size",28)
 title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 bar.add_child(title_label)
 for language in ["en","ar","pt"]:
  var b = make_button(language.to_upper(),func(): set_language(language))
  bar.add_child(b)
 bar.add_child(make_button("↻",reset_recipe))
 detail = Label.new()
 detail.position = Vector2(20,105)
 detail.size = Vector2(1240,42)
 detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 detail.add_theme_font_size_override("font_size",26)
 detail.add_theme_color_override("font_color",Color("#173b35"))
 detail.add_theme_color_override("font_outline_color",Color("#fff3dd"))
 detail.add_theme_constant_override("outline_size",7)
 hud.add_child(detail)
 tally = Label.new()
 tally.position = Vector2(20,149)
 tally.size = Vector2(1240,35)
 tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 tally.add_theme_font_size_override("font_size",21)
 tally.add_theme_color_override("font_color",Color("#173b35"))
 tally.add_theme_color_override("font_outline_color",Color("#fff3dd"))
 tally.add_theme_constant_override("outline_size",6)
 hud.add_child(tally)
 meter = ProgressBar.new()
 meter.position = Vector2(440,189)
 meter.size = Vector2(400,18)
 meter.max_value = 100
 meter.show_percentage = false
 hud.add_child(meter)
 var bottom = PanelContainer.new()
 bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 bottom.offset_top = -102
 style_panel(bottom,Color("#123d39"))
 hud.add_child(bottom)
 actions = HBoxContainer.new()
 actions.alignment = BoxContainer.ALIGNMENT_CENTER
 actions.add_theme_constant_override("separation",10)
 bottom.add_child(actions)

func style_panel(p: PanelContainer,c: Color) -> void:
 var s = StyleBoxFlat.new()
 s.bg_color = c
 s.content_margin_left = 16
 s.content_margin_right = 16
 s.content_margin_top = 10
 s.content_margin_bottom = 10
 p.add_theme_stylebox_override("panel",s)

func make_button(label: String, action: Callable) -> Button:
 var b = Button.new()
 b.text = label
 b.custom_minimum_size = Vector2(92,66)
 b.add_theme_font_size_override("font_size",24)
 for state in ["normal","hover","pressed","disabled"]:
  var s = StyleBoxFlat.new()
  s.bg_color = Color("#277e70") if state=="normal" else Color("#b76c32")
  if state=="disabled": s.bg_color = Color("#566c63")
  s.set_corner_radius_all(16)
  s.content_margin_left = 14
  s.content_margin_right = 14
  b.add_theme_stylebox_override(state,s)
 b.pressed.connect(action)
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
 refresh()

func next_recipe() -> void:
 level = (level+1)%RECIPES.size()
 save_game()
 start_recipe()

func requirements_met() -> bool:
 if sauce_amount < 8: return false
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
 detail.text = t(7)+": "+t(20+theme)
 tally.text = ""
 meter.visible = phase >= 0 and phase <= 3
 if phase == -1:
  add_action(t(5),start_recipe)
  add_action(t(7)+": "+t(20+theme),toggle_theme)
 elif phase == 0:
  detail.text = t(1)
  tally.text = t(22)
  meter.value = stretch*100
  add_action("✓",advance,stretch>=0.99)
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
  tally.text = "60% – 85%"
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
  detail.text = t(15)+"  ★★★"
  add_action(t(6),next_recipe)
  add_action(t(7),toggle_theme)
  add_action(t(5),start_recipe)

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
 elif phase == 1 and requirements_met():
  phase = 2
 elif phase == 2 and not baking and heat>=0.60 and heat<=0.85:
  phase = 3
 elif phase == 3 and sliced>=3:
  phase = 4
  save_game()
 refresh()

func _process(delta: float) -> void:
 if baking:
  heat = minf(1.0,heat+delta*0.17)
  meter.value = heat*100
  dough.material_override = mat(Color("#efd29b").lerp(Color("#b97135"),heat))
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
 if phase < 0 or phase > 3 or phase == 2: return
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  var p = point_on_pizza(event.position)
  if event.pressed and p.length() <= 1.75:
   dragging = true
   last_world = p
   drag_start = p
   travelled = 0
   if phase==1 and selected!="sauce": place_topping(p)
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
   if stretch>=0.99: refresh()
   else: meter.value = stretch*100
  elif phase==1 and selected=="sauce":
   sauce_amount = mini(12,sauce_amount+1)
   sauce.visible = true
   sauce.scale = Vector3(sauce_amount/12.0,1,sauce_amount/12.0)
   if sauce_amount==8: refresh()
   else: meter.value = minf(100,sauce_amount/8.0*50+placed.size()*50.0/(RECIPES[level].size()*2))
  last_world = p

func place_topping(p: Vector3) -> void:
 if p.length()>1.38 or placed.size()>=40: return
 var kind = selected
 var pos = Vector3(p.x,0.32,p.z)
 if not asset(topping_root,kind,pos,0.29):
  disc(topping_root,0.12,0.07,pos,COLORS[KINDS.find(kind)])
 placed.append(kind)
 refresh()

func cut_line(a: Vector3,b: Vector3) -> void:
 var axis = (b-a).normalized()
 if axis.length()<0.01: return
 var cut = box(cuts,Vector3(0.034,0.025,3.1),Vector3(0,0.45,0),Color("#754021"))
 cut.rotation.y = atan2(axis.x,axis.z)
 sliced += 1
 refresh()
