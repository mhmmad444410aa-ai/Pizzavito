extends Control
# Rebuilt touch-first 2.5D cooking studio. Old 3D prototype is retained in git history.
const C = Vector2(570,366)
const R = 235.0
const ART = "res://rebuild/art/"
const LANGS = ["en","ar","pt"]
const FOODS = ["tomato","mushroom","cheese","pepper","onion","olive","corn","carrot","basil"]
const NAMES = {
 "tomato":["Tomato","طماطم","Tomate"],"mushroom":["Mushroom","فطر","Cogumelo"],"cheese":["Cheese","جبنة","Queijo"],"pepper":["Pepper","فلفل","Pimentão"],"onion":["Onion","بصل","Cebola"],"olive":["Olive","زيتون","Azeitona"],"corn":["Corn","ذرة","Milho"],"carrot":["Carrot","جزر","Cenoura"],"basil":["Basil","ريحان","Manjericão"],"sauce":["Tomato sauce","صلصة الطماطم","Molho de tomate"],"white":["Cream sauce","صلصة بيضاء","Molho branco"]
}
const BASE = [
 ["Margherita","مارغريتا","Margherita",["tomato","cheese","basil"]],
 ["Forest","فطر الغابة","Floresta",["mushroom","cheese","onion"]],
 ["Garden","الحديقة","Horta",["pepper","tomato","onion"]],
 ["Sunshine","الشمس","Sol",["corn","cheese","carrot"]],
 ["Olive harvest","حصاد الزيتون","Colheita",["olive","tomato","basil"]],
 ["Rainbow","قوس قزح","Arco-íris",["pepper","corn","carrot","tomato"]],
 ["Cheese garden","حديقة الجبن","Jardim de queijo",["cheese","mushroom","basil"]],
 ["Picnic","نزهة","Piquenique",["olive","corn","pepper"]],
 ["Market","السوق","Feira",["carrot","onion","tomato"]],
 ["Party special","الحفلة","Festa",["cheese","corn","olive","mushroom"]]
]
const SHAPES = ["round","heart","square","star","mini"]
const KITCHENS = ["trattoria","garden","coast","night"]
const KITCHEN_NAMES = [["Trattoria","المطبخ الإيطالي","Trattoria"],["Garden cafe","مقهى الحديقة","Café jardim"],["Coastal bakery","مخبز الساحل","Padaria costeira"],["Evening bistro","مطعم المساء","Bistrô noturno"]]
var lang = 0
var kitchen = 0
var screen = "home"
var phase = 0
var recipe = 0
var page = 0
var free = false
var book: Array[Dictionary] = []
var scores: Dictionary = {}
var tex: Dictionary = {}
var ui: Control
var status: Label
var progress_label: Label
var advance_button: Button
var selected = "tomato"
var sauce_kind = "sauce"
var shape_kind = "round"
var dough_progress = 0.0
var sauce_cells: Dictionary = {}
var sauce_dabs: Array[Vector2] = []
var toppings: Array[Dictionary] = []
var cuts: Array[float] = []
var dragging = false
var last = Vector2.ZERO
var stroke_start = Vector2.ZERO
var roller_at = C
var dragging_tool = false
var heat = 0.0
var baking = false
var oven_state = 0
var oven_motion = 0.0
var oven_button: Button
var pack_stage = 0
var pack_button: Button
var bake_retry = false
var baked = false
var finish_score = 0
var bake_quality = 0
var pack_anim = 0.0
var tick = 0.0
var tray_rects: Dictionary = {}
var cut_hint = false
var audio: AudioStreamPlayer
var pop: AudioStreamWAV
var manifest: Dictionary = {}
var model_view: SubViewportContainer
var preview_world: SubViewport
var preview_pivot: Node3D
var old_pointer = Vector2.ZERO
var unlocked = 0
var ingredient_labels: Dictionary = {}
var selected_buttons: Dictionary = {}
var sauce_goal_cells: Array[Vector2i] = []
var cut_path: Array[Vector2] = []
var materials_2d: Dictionary = {}
var actual_previews: Dictionary = {}
var packing = false
var pack_time = 0.0
var shopping: Dictionary = {}
var market_feedback = ""
var topping_fx: Array[Dictionary] = []
var shape_options = ["round","heart","square","star","mini","flower","oval","triangle","diamond","clover"]
var action_accuracy = 0
var action_total = 0
var button_texture: Texture2D
var cut_error = 0.0

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 build_recipes()
 var cfg = ConfigFile.new()
 if cfg.load("user://studio_progress_v3.cfg")==OK:
  lang = clampi(int(cfg.get_value("studio","lang",0)),0,2)
  kitchen = clampi(int(cfg.get_value("studio","kitchen",0)),0,3)
  scores = cfg.get_value("studio","scores",{})
  while unlocked<book.size()-1 and int(scores.get(str(unlocked),0))>0: unlocked+=1
 for key in KITCHENS+FOODS+["sauce","white","hero","roller","oven","box","cutter"]:
  tex[key] = load(ART+str(key)+".svg")
 for key in ["wood","marble","tile","stone","prep","sauceboard","bakeboard","cutboard","packboard"]:
  var path = "res://assets/imported/surfaces/"+key+"_color.jpg"
  if ResourceLoader.exists(path): materials_2d[key] = load(path)
 for key in FOODS:
  var path = "res://assets/imported/previews/"+key+".png"
  if ResourceLoader.exists(path): actual_previews[key] = load(path)
 if ResourceLoader.exists("res://assets/imported/interface/button.png"):
  button_texture = load("res://assets/imported/interface/button.png")
 if FileAccess.file_exists("res://assets/imported/manifest.json"):
  var m = JSON.parse_string(FileAccess.get_file_as_string("res://assets/imported/manifest.json"))
  if m is Dictionary: manifest = m
 ui = Control.new()
 ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(ui)
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 setup_audio()
 rebuild_ui()
 if "--smoke-test" in OS.get_cmdline_user_args():
  smoke()

func tr3(en: String, ar: String, pt: String) -> String:
 return [en,ar,pt][lang]

func food_name(key: String) -> String:
 return NAMES[key][lang]

func build_recipes() -> void:
 for i in range(5):
  for j in range(BASE.size()):
   var base: Array = BASE[j]
   var names: Array = base.slice(0,3)
   if i>0:
    names = [str(base[0])+" · "+["","Heart","Square","Star","Mini"][i],str(base[1])+" · "+["","قلب","مربع","نجمة","صغيرة"][i],str(base[2])+" · "+["","Coração","Quadrada","Estrela","Mini"][i]]
   book.append({"names":names,"shape":SHAPES[i],"sauce":"white" if (j+i)%4==1 else "sauce","ingredients":base[3].duplicate(),"slices":[4,6,8,6,4][i],"portion":4 if i==4 else 5+(j%2)})
   
func persist() -> void:
 var cfg = ConfigFile.new()
 cfg.set_value("studio","lang",lang)
 cfg.set_value("studio","kitchen",kitchen)
 cfg.set_value("studio","scores",scores)
 cfg.set_value("studio","unlocked",unlocked)
 cfg.save("user://studio.cfg")

func panel_style(color: Color, edge: Color, radius: int=22) -> StyleBoxFlat:
 var s = StyleBoxFlat.new()
 s.bg_color = color
 s.set_corner_radius_all(radius)
 s.set_border_width_all(3)
 s.border_color = edge
 s.shadow_color = Color(0.12,0.09,0.06,0.23)
 s.shadow_size = 5
 s.shadow_offset = Vector2(0,4)
 return s

func panel(parent: Control, area: Rect2, col: Color, edge: Color) -> Panel:
 var p = Panel.new()
 p.position = area.position
 p.size = area.size
 p.mouse_filter = Control.MOUSE_FILTER_IGNORE
 p.add_theme_stylebox_override("panel",panel_style(col,edge))
 parent.add_child(p)
 return p

func label(parent: Control, value: String, area: Rect2, size_px: int=25, col: Color=Color("#314d42"), centre: bool=true) -> Label:
 var l = Label.new()
 l.text = value
 l.position = area.position
 l.size = area.size
 l.add_theme_font_size_override("font_size",size_px)
 l.add_theme_color_override("font_color",col)
 l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centre else HORIZONTAL_ALIGNMENT_LEFT
 l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(l)
 return l

func button(parent: Control, value: String, area: Rect2, action: Callable, accent: bool=false, size_px: int=25) -> Button:
 var b = Button.new()
 b.text = value
 b.position = area.position
 b.size = area.size
 b.add_theme_font_size_override("font_size",size_px)
 for state in ["normal","hover","pressed","disabled"]:
  var color = Color("#447d65") if accent else Color("#fff1d4")
  if state=="hover": color = color.lightened(0.10)
  if state=="pressed": color = color.darkened(0.12)
  if state=="disabled": color = Color("#b7b7a0")
  var edge = Color("#2b5b48") if accent else Color("#c39160")
  if button_texture!=null and screen!="home" and accent and state!="disabled":
   var skin = StyleBoxTexture.new()
   skin.texture = button_texture
   for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
    skin.set_texture_margin(side,9.0)
    skin.set_content_margin(side,9.0)
   skin.modulate_color = Color.WHITE if state=="normal" else (Color("#dce8d8") if state=="pressed" else Color("#f4fff0"))
   b.add_theme_stylebox_override(state,skin)
  else:
   b.add_theme_stylebox_override(state,panel_style(color,edge,18))
 b.add_theme_color_override("font_color",Color("#fff8df") if accent else Color("#4b3a2f"))
 b.add_theme_color_override("font_hover_color",Color.WHITE if accent else Color("#4b3a2f"))
 b.add_theme_color_override("font_pressed_color",Color.WHITE if accent else Color("#4b3a2f"))
 var glyph = icon_for(value)
 if not glyph.is_empty():
  b.icon = load("res://rebuild/icons/"+glyph+".svg")
  b.add_theme_constant_override("icon_max_width",34)
  b.add_theme_color_override("icon_normal_color",Color.WHITE if accent else Color("#735138"))
  b.add_theme_color_override("icon_hover_color",Color.WHITE if accent else Color("#735138"))
 b.pressed.connect(func():
  click()
  action.call())
 parent.add_child(b)
 return b

func icon_for(value: String) -> String:
 if value==tr3("PLAY  ›","العب  ‹","JOGAR  ›"): return "play"
 if value==tr3("Recipe book","دفتر الوصفات","Receitas"): return "book-open"
 if value==tr3("Settings","الإعدادات","Ajustes"): return "settings"
 if value==tr3("Free kitchen","المطبخ الحر","Cozinha livre"): return "chef-hat"
 return ""

func image_node(parent: Control,key: String,area: Rect2) -> TextureRect:
 var v = TextureRect.new()
 v.position = area.position
 v.size = area.size
 if not tex.has(key) and key.begins_with("recipe_"):
  tex[key] = load(ART+key+".svg")
 v.texture = tex.get(key)
 v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 v.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 v.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(v)
 return v

func clear_ui() -> void:
 for child in ui.get_children():
  ui.remove_child(child)
  child.queue_free()
 tray_rects.clear()
 ingredient_labels.clear()
 selected_buttons.clear()
 status = null
 progress_label = null
 advance_button = null

func rebuild_ui() -> void:
 clear_ui()
 match screen:
  "home": home_ui()
  "book": book_ui()
  "kitchens": kitchens_ui()
  "settings": settings_ui()
  "gallery": gallery_ui()
  "cook": cook_ui()
  "market": market_ui()
  "result": result_ui()
 queue_redraw()

func go(value: String) -> void:
 screen = value
 dragging = false
 dragging_tool = false
 rebuild_ui()

func home_ui() -> void:
 panel(ui,Rect2(37,38,566,642),Color("#fff1d9"),Color("#c99360"))
 label(ui,"PIZZAVITO",Rect2(73,72,490,90),66,Color("#355e4c"))
 label(ui,tr3("Little pizza studio","استوديو البيتزا الصغير","Pequeno estúdio de pizza"),Rect2(72,158,490,60),31,Color("#a95638"))
 button(ui,tr3("PLAY  ›","العب  ‹","JOGAR  ›"),Rect2(82,248,475,100),func(): go("book"),true,39)
 button(ui,tr3("Free kitchen","المطبخ الحر","Cozinha livre"),Rect2(82,365,475,76),func(): start_recipe(0,true),false,30)
 button(ui,tr3("Kitchens","المطابخ","Cozinhas"),Rect2(82,456,230,72),func(): go("kitchens"))
 button(ui,tr3("Settings","الإعدادات","Ajustes"),Rect2(326,456,231,72),func(): go("settings"))
 button(ui,tr3("Ingredient gallery","معرض المكونات","Galeria de ingredientes"),Rect2(82,544,475,65),func(): go("gallery"),false,24)
 image_node(ui,"hero",Rect2(685,126,470,470))
 label(ui,tr3("50 recipes • 4 kitchens","٥٠ وصفة • ٤ مطابخ","50 receitas • 4 cozinhas"),Rect2(640,615,610,55),30,Color("#fff6dc"))
 
func header(title: String, back: String) -> void:
 panel(ui,Rect2(24,18,1232,76),Color("#fff0d6"),Color("#bd8959"))
 button(ui,tr3("‹ Home","الرئيسية ›","‹ Início") if back=="home" else tr3("‹ Back","رجوع ›","‹ Voltar"),Rect2(40,27,180,58),func(): go(back),false,24)
 label(ui,title,Rect2(240,25,800,61),35,Color("#355b4a"))

func book_ui() -> void:
 header(tr3("Recipe book","دفتر الوصفات","Livro de receitas"),"home")
 var first = page*6
 for i in range(first,mini(first+6,book.size())):
  var index = i
  var col = (i-first)%3
  var row = int((i-first)/3)
  var area = Rect2(45+col*399,115+row*238,380,219)
  var card = button(ui,"",area,func(): start_recipe(index,false),i==unlocked)
  var locked = i>unlocked
  card.disabled = locked
  var rec = book[i]
  image_node(card,"recipe_"+str(i),Rect2(13,17,150,150))
  label(card,str(i+1)+". "+str(rec["names"][lang]),Rect2(169,13,195,72),23,Color("#355b4a"),true)
  var stars = int(scores.get(str(i),0))
  label(card,tr3("Locked","مغلقة","Bloqueada") if locked else "★".repeat(stars)+"☆".repeat(3-stars),Rect2(169,83,195,42),25,Color("#82654d") if locked else Color("#d08b35"))
  if locked:
   card.modulate = Color("#aaa49b")
   label(card,"🔒",Rect2(18,18,64,64),36,Color("#554b42"))
  var ingredients: Array = rec["ingredients"]
  for n in range(mini(ingredients.size(),4)):
   image_node(card,str(ingredients[n]),Rect2(169+n*46,128,43,43))
  label(card,shape_label(str(rec["shape"]))+" · "+str(rec["slices"])+" "+tr3("slices","شرائح","fatias"),Rect2(9,174,362,36),20,Color("#74543c"))
 button(ui,"‹",Rect2(420,600,98,82),func(): change_page(-1),false,40)
 label(ui,str(page+1)+" / "+str(ceili(book.size()/6.0)),Rect2(525,610,230,60),32,Color("#fff1d3"))
 button(ui,"›",Rect2(762,600,98,82),func(): change_page(1),false,40)

func shape_label(key: String) -> String:
 match key:
  "heart": return tr3("Heart","قلب","Coração")
  "square": return tr3("Square","مربع","Quadrada")
  "star": return tr3("Star","نجمة","Estrela")
  "mini": return tr3("Mini","صغيرة","Mini")
  "flower": return tr3("Flower","زهرة","Flor")
  "oval": return tr3("Oval","بيضاوية","Oval")
  "triangle": return tr3("Triangle","مثلث","Triângulo")
  "diamond": return tr3("Diamond","ماسة","Losango")
  "clover": return tr3("Clover","برسيم","Trevo")
  _: return tr3("Round","دائرية","Redonda")

func change_page(delta: int) -> void:
 page = clampi(page+delta,0,ceili(book.size()/6.0)-1)
 rebuild_ui()

func kitchens_ui() -> void:
 header(tr3("Choose a kitchen","اختر المطبخ","Escolha a cozinha"),"home")
 for i in range(4):
  var index = i
  var area = Rect2(64+(i%2)*586,122+int(i/2)*270,566,248)
  var card = button(ui,"",area,func(): select_kitchen(index))
  image_node(card,KITCHENS[i],Rect2(10,10,546,178))
  label(card,str(KITCHEN_NAMES[i][lang])+("  ✓" if i==kitchen else ""),Rect2(12,190,542,45),29)
 
func select_kitchen(index: int) -> void:
 kitchen = index
 persist()
 go("home")

func settings_ui() -> void:
 header(tr3("Settings","الإعدادات","Ajustes"),"home")
 panel(ui,Rect2(257,133,766,465),Color("#fff1d7"),Color("#c99360"))
 label(ui,tr3("Language","اللغة","Idioma"),Rect2(290,160,700,65),38)
 for i in range(3):
  var index = i
  button(ui,["English","العربية","Português"][i]+("  ✓" if lang==i else ""),Rect2(350,245+i*88,580,73),func(): set_lang(index),lang==i,31)
 label(ui,tr3("Offline • No ads • No music","دون إنترنت • دون إعلانات • دون موسيقى","Offline • Sem anúncios • Sem música"),Rect2(275,530,730,45),24)

func set_lang(index: int) -> void:
 lang = index
 persist()
 rebuild_ui()

func start_recipe(index: int, freestyle: bool) -> void:
 if not freestyle and (index<0 or index>=book.size() or index>unlocked): return
 recipe = clampi(index,0,book.size()-1)
 free = freestyle
 var rec = book[recipe]
 shape_kind = str(rec["shape"]) if not free else "round"
 sauce_kind = str(rec["sauce"]) if not free else "sauce"
 selected = str(rec["ingredients"][0])
 phase = 0
 dough_progress = 0.0
 sauce_cells.clear()
 sauce_dabs.clear()
 toppings.clear()
 cuts.clear()
 heat = 0.0
 baking = false
 baked = false
 oven_state = 0
 oven_motion = 0.0
 pack_stage = 0
 bake_retry = false
 bake_quality = 0
 finish_score = 0
 pack_anim = 0.0
 roller_at = C
 cut_hint = true
 packing = false
 pack_time = 0.0
 cut_path.clear()
 topping_fx.clear()
 action_accuracy=0
 action_total=0
 cut_error=0.0
 shopping.clear()
 market_feedback=""
 build_sauce_grid()
 if not free and recipe>=3:
  go("market")
 else:
  go("cook")

func title_for_phase() -> String:
 match phase:
  0: return tr3("Roll the dough","افرد العجين","Abra a massa")
  1: return tr3("Spread the sauce","وزّع الصلصة","Espalhe o molho")
  2: return tr3("Decorate your pizza","زيّن البيتزا","Decore a pizza")
  3: return tr3("Bake until golden","اخبز حتى تصبح ذهبية","Asse até dourar")
  4: return tr3("Slice it!","قطّع البيتزا!","Corte a pizza!")
  _: return tr3("Pack & serve","غلّف وقدّم","Embale e sirva")

func cook_ui() -> void:
 panel(ui,Rect2(20,16,1240,88),Color("#fff0d7"),Color("#c48b59"))
 button(ui,"‹",Rect2(32,28,72,62),func(): go("home"),false,37)
 label(ui,title_for_phase(),Rect2(114,24,620,66),38)
 for i in range(6):
  var step_col = Color("#4c876c") if i<=phase else Color("#d5b893")
  panel(ui,Rect2(762+i*76,35,57,45),step_col,step_col.darkened(.18))
  label(ui,str(i+1),Rect2(762+i*76,35,57,45),25,Color("#fff6dd"))
 panel(ui,Rect2(24,124,128,478),Color("#fff1d9"),Color("#c68e5c"))
 label(ui,tr3("YOUR ORDER","طلبك","SEU PEDIDO"),Rect2(30,136,116,40),23,Color("#a65338"))
 label(ui,tr3("Free kitchen","المطبخ الحر","Cozinha livre") if free else str(book[recipe]["names"][lang]),Rect2(30,177,116,80),20)
 image_node(ui,"recipe_"+str(recipe),Rect2(30,260,116,116))
 label(ui,shape_label(shape_kind)+"\n"+food_name(sauce_kind),Rect2(30,382,116,90),19)
 var order_items: Array = book[recipe]["ingredients"] if not free else []
 for i in range(mini(order_items.size(),4)):
  image_node(ui,str(order_items[i]),Rect2(31+(i%2)*55,480+int(i/2)*51,50,48))
 panel(ui,Rect2(980,124,276,478),Color("#fff1d9"),Color("#c68e5c"))
 status = label(ui,"",Rect2(995,136,246,106),27)
 progress_label = label(ui,"",Rect2(995,527,246,58),23,Color("#a85a3d"))
 match phase:
  0:
   image_node(ui,"roller",Rect2(999,270,235,80))
   label(ui,tr3("Drag across the dough","مرّر فوق العجين","Deslize sobre a massa"),Rect2(1000,365,236,70),22)
   if free:
    button(ui,shape_label(shape_kind)+"  ›",Rect2(995,440,246,67),cycle_shape,false,23)
  1:
   image_node(ui,sauce_kind,Rect2(1040,264,156,156))
   if free:
    button(ui,tr3("Switch sauce","بدّل الصلصة","Trocar molho"),Rect2(997,443,242,64),func(): switch_sauce(),false,22)
  2: build_tray()
  3:
   image_node(ui,"oven",Rect2(1013,269,213,177))
   oven_button = button(ui,"",Rect2(996,447,244,62),oven_action,true,24)
  4:
   image_node(ui,"cutter",Rect2(1015,271,208,155))
   button(ui,tr3("Help cut","مساعدة القطع","Ajudar corte"),Rect2(996,447,244,62),assist_cut,false,23)
  5:
   image_node(ui,"box",Rect2(1010,250,216,160))
   pack_button = button(ui,"",Rect2(996,447,244,62),advance,true,24)
 panel(ui,Rect2(20,620,1240,82),Color("#fff1d9"),Color("#c48b59"))
 button(ui,tr3("Restart","إعادة","Reiniciar"),Rect2(33,632,175,58),func(): start_recipe(recipe,free),false,24)
 if phase==2:
  button(ui,tr3("Undo","تراجع","Desfazer"),Rect2(224,632,160,58),undo_topping,false,23)
 advance_button = button(ui,tr3("Next  ›","التالي  ‹","Próximo  ›"),Rect2(938,631,308,60),advance,true,29)
 if phase==0 or phase==1 or phase==2:
  button(ui,tr3("Help","مساعدة","Ajuda"),Rect2(430,632,170,58),assist_step,false,24)
 if not free:
  label(ui,tr3("LEVEL ","المرحلة ","NÍVEL ")+str(recipe+1),Rect2(650,634,230,50),25,Color("#785139"))
 update_status()

func build_tray() -> void:
 var list: Array = FOODS if free else book[recipe]["ingredients"]
 var cols = 3 if list.size()>4 else 2
 var card_w = 80 if cols==3 else 122
 var card_h = 85 if cols==3 else 118
 for i in range(list.size()):
  var key = str(list[i])
  var area = Rect2(993+(i%cols)*(card_w+5),244+int(i/cols)*(card_h+5),card_w,card_h)
  var b = button(ui,"",area,func(): select_food(key),false)
  selected_buttons[key] = b
  var img = image_node(b,key,Rect2(6,3,card_w-12,card_h-36))
  if actual_previews.has(key): img.texture = actual_previews[key]
  ingredient_labels[key] = label(b,food_name(key),Rect2(2,card_h-34,card_w-4,32),17 if cols==2 else 12,Color("#594738"))
  tray_rects[key] = area

func select_food(key: String) -> void:
 selected = key
 update_status()

func switch_sauce() -> void:
 sauce_kind = "white" if sauce_kind=="sauce" else "sauce"
 sauce_cells.clear()
 sauce_dabs.clear()
 rebuild_ui()

func undo_topping() -> void:
 if not toppings.is_empty(): toppings.pop_back()
 update_status()
 queue_redraw()

func sauce_target() -> int:
 return maxi(1,ceili(sauce_goal_cells.size()*(.48 if free else .48+minf(float(recipe)*.008,.32))))

func topping_target() -> int:
 return 8 if free else ingredient_quota()*book[recipe]["ingredients"].size()

func required_slices() -> int:
 return int(book[recipe]["slices"])/2

func topping_count(key: String) -> int:
 var total = 0
 for item in toppings:
  if item["key"]==key: total+=1
 return total

func fulfilled() -> int:
 if free: return mini(toppings.size(),topping_target())
 var total = 0
 for key in book[recipe]["ingredients"]:
  total += mini(topping_count(str(key)),ingredient_quota())
 return total

func ready_for_next() -> bool:
 match phase:
  0: return dough_progress>=1.0
  1: return sauce_cells.size()>=sauce_target()
  2: return fulfilled()>=topping_target()
  3: return baked
  4: return cuts.size()>=required_slices()
  _: return true

func update_status() -> void:
 if not is_instance_valid(status): return
 match phase:
  0:
   status.text = tr3("Roll in different directions","افرد باتجاهات مختلفة","Role em várias direções")
   progress_label.text = str(roundi(dough_progress*100))+"%"
  1:
   status.text = tr3("Cover the pizza evenly","غطّ العجين بالتساوي","Cubra a massa por igual")
   progress_label.text = str(mini(sauce_cells.size(),sauce_target()))+" / "+str(sauce_target())
  2:
   status.text = food_name(selected)+"\n"+tr3("Tap or drag to place","اضغط أو اسحب لتوزيع المكونات","Toque ou arraste")
   progress_label.text = str(fulfilled())+" / "+str(topping_target())
   if not free and recipe>=5: status.text = food_name(selected)+"\n"+tr3("Place on the glowing ring","ضع المكون في الحلقة المضيئة","Coloque no círculo brilhante")
   for key in ingredient_labels:
    var entry: Label = ingredient_labels[key]
    var count = topping_count(str(key))
    entry.text = food_name(str(key))+" "+str(count)+("/"+str(ingredient_quota()) if not free else "")
    var btn: Button = selected_buttons[key]
    btn.modulate = Color("#a7e5bf") if key==selected else Color.WHITE
  3:
   var messages = [tr3("Slide pizza into oven","أدخل البيتزا إلى الفرن","Coloque a pizza no forno"),tr3("Loading pizza…","جارٍ إدخال البيتزا","Colocando pizza…"),tr3("Close door & start","أغلق الباب وابدأ الخبز","Feche e ligue"),tr3("Stop in the green zone","أوقف الفرن في المنطقة الخضراء","Pare na zona verde"),tr3("Taking pizza out…","جارٍ إخراج البيتزا","Retirando pizza…"),tr3("Golden and ready!","ذهبية وجاهزة!","Dourada e pronta!")]
   status.text = messages[oven_state]
   if bake_retry and oven_state==2: status.text=tr3("Try the green zone again","حاول إصابة المنطقة الخضراء","Tente a zona verde novamente")
   progress_label.text = str(roundi(heat*100))+"%"
   if is_instance_valid(oven_button):
    oven_button.text = [tr3("Load pizza","أدخل البيتزا","Colocar pizza"),"…",tr3("Start oven","شغّل الفرن","Ligar forno"),tr3("STOP OVEN","أوقف الفرن","PARAR FORNO"),"…",tr3("Done","تم","Pronto")][oven_state]
    oven_button.disabled = oven_state==1 or oven_state==4 or oven_state==5
  4:
   status.text = tr3("Swipe across the centre","اسحب عبر المنتصف","Deslize pelo centro")
   progress_label.text = str(cuts.size())+" / "+str(required_slices())
  5:
   var tasks = [tr3("Slide pizza into box","ضع البيتزا داخل العلبة","Coloque na caixa"),tr3("Fold the lid","أغلق الغطاء","Feche a tampa"),tr3("Seal the box","ضع ملصق الإغلاق","Sele a caixa"),tr3("Ready to serve!","جاهزة للتقديم!","Pronta para servir!")]
   status.text = tasks[pack_stage]
   progress_label.text = str(pack_stage)+" / 3"
   if is_instance_valid(pack_button):
    pack_button.text = [tr3("Pack pizza","ضع في العلبة","Embalar"),tr3("Close lid","أغلق العلبة","Fechar"),tr3("Add seal","ضع الملصق","Selar"),tr3("Serve","قدّم","Servir")][pack_stage]
    pack_button.disabled = packing
 if is_instance_valid(advance_button):
  advance_button.disabled = not ready_for_next()
  if phase==3 and baking:
   advance_button.disabled = false
   advance_button.text = tr3("Stop oven","أوقف الفرن","Parar forno")
  elif phase==3:
   advance_button.text = tr3("Next  ›","التالي  ‹","Próximo  ›")
  elif phase==5:
   advance_button.text = tr3("Serve pizza","قدّم البيتزا","Servir pizza") if pack_stage==3 else tr3("Complete step","أكمل الخطوة","Concluir etapa")
   advance_button.disabled = packing
 queue_redraw()

func oven_action() -> void:
 match oven_state:
  0:
   oven_state=1
   oven_motion=0.0
  2: start_bake()
  3: stop_bake()
 update_status()

func oven_bounds() -> Vector2:
 var width = .24 if free else maxf(.075,.24-float(recipe)*.0035)
 return Vector2(.75-width*.5,.75+width*.5)

func start_bake() -> void:
 if oven_state!=2: return
 heat=0.0
 oven_state=3
 baking=true
 baked=false
 update_status()

func stop_bake() -> void:
 if not baking: return
 baking=false
 var zone=oven_bounds()
 bake_quality=3 if heat>=zone.x and heat<=zone.y else (2 if heat>=zone.x-.13 and heat<=zone.y+.12 else 1)
 if not free and recipe>=4 and bake_quality==1:
  bake_retry=true
  oven_state=2
  heat=0.0
  baked=false
 else:
  oven_state=4
  oven_motion=0.0
 click()
 update_status()

func advance() -> void:
 if phase==3 and baking:
  stop_bake()
  return
 if not ready_for_next(): return
 if phase==5:
  if packing: return
  if pack_stage<3:
   packing=true
   pack_time=0.0
   update_status()
   return
  finish_score = maxi(1,mini(3,bake_quality))
  if not free and recipe>=5 and action_total>0 and float(action_accuracy)/float(action_total)<.55: finish_score=mini(finish_score,2)
  if not free:
   scores[str(recipe)] = maxi(int(scores.get(str(recipe),0)),finish_score)
   if recipe==unlocked: unlocked = mini(book.size()-1,unlocked+1)
  if not "--smoke-test" in OS.get_cmdline_user_args(): persist()
  go("result")
  return
 phase+=1
 if phase==5:
  pack_anim=0.0
  pack_stage=0
  packing=false
 dragging = false
 dragging_tool = false
 cut_path.clear()
 click()
 rebuild_ui()

func result_ui() -> void:
 panel(ui,Rect2(255,72,770,576),Color("#fff0d7"),Color("#c99360"))
 label(ui,tr3("Pizza served!","تم تقديم البيتزا!","Pizza servida!"),Rect2(280,88,720,75),48,Color("#3c7256"))
 image_node(ui,"recipe_"+str(recipe),Rect2(495,177,290,290))
 label(ui,"★".repeat(finish_score)+"☆".repeat(3-finish_score),Rect2(300,465,680,60),48,Color("#d79432"))
 button(ui,tr3("Recipe book","دفتر الوصفات","Receitas"),Rect2(295,552,330,67),func(): go("book"),false,26)
 button(ui,tr3("Next pizza","البيتزا التالية","Próxima pizza"),Rect2(652,552,330,67),func(): start_recipe(mini(recipe+1,unlocked),false),true,26)

func radius_for(a: float) -> float:
 match shape_kind:
  "heart":
   return R*(1.0-0.19*sin(a)-0.12*cos(2*a)+0.08*cos(4*a))
  "square": return R*0.76/maxf(absf(cos(a)),absf(sin(a)))
  "star": return R*(0.83+0.17*cos(5*a))
  "mini": return R*0.73
  "flower": return R*(0.85+0.13*cos(6*a))
  "oval": return R*0.76/sqrt(pow(cos(a)*0.76,2)+pow(sin(a),2))
  "triangle": return R*.49/maxf(.49,cos(fposmod(a+PI/6.0,TAU/3.0)-PI/3.0))
  "diamond": return R*.97/(absf(cos(a))+absf(sin(a)))
  "clover": return R*(.83+.15*cos(4*a))
  _: return R

func inside(p: Vector2,factor: float=1.0) -> bool:
 var q = p-C
 return q.length()<=radius_for(q.angle())*factor

func outline(scale_factor: float, shift: Vector2=Vector2.ZERO, start: float=0.0, sweep: float=TAU) -> PackedVector2Array:
 var pts = PackedVector2Array()
 if sweep<TAU-0.01: pts.append(C+shift)
 var count = maxi(10,roundi(100.0*sweep/TAU))
 var point_count = count+1 if sweep<TAU-0.01 else count
 for i in range(point_count):
  var a = start+sweep*float(i)/float(count)
  pts.append(C+shift+Vector2(cos(a),sin(a))*radius_for(a)*scale_factor)
 return pts

func layer(scale_factor: float,color: Color,shift: Vector2=Vector2.ZERO,start: float=0.0,sweep: float=TAU) -> void:
 draw_colored_polygon(outline(scale_factor,shift,start,sweep),color)

func draw_image(key: String,area: Rect2,tint: Color=Color.WHITE) -> void:
 var texture = tex.get(key)
 if texture is Texture2D: draw_texture_rect(texture,area,false,tint)

func _draw() -> void:
 if tex.is_empty(): return
 draw_image(KITCHENS[kitchen],Rect2(0,0,1280,720))
 if screen!="cook":
  draw_rect(Rect2(0,0,1280,720),Color(0.15,0.18,0.13,0.25))
  return
 # An isolated bright work surface keeps the cooking action separate from the background.
 draw_style_box(panel_style(Color("#754b32"),Color("#ad8558"),38),Rect2(166,116,800,496))
 var material_key = ["prep","sauceboard","wood","bakeboard","cutboard","packboard"][phase]
 if not materials_2d.has(material_key): material_key = ["wood","marble","tile","stone"][kitchen]
 if materials_2d.has(material_key):
  draw_texture_rect(materials_2d[material_key],Rect2(177,127,778,474),false,Color(0.87,0.83,0.76))
 draw_style_box(panel_style(Color(0.98,0.86,0.69,0.22),Color("#b28857"),35),Rect2(183,133,766,462))
 if phase!=3 and phase!=5:
  draw_circle(C+Vector2(0,9),249,Color(0.23,0.13,0.06,0.25))
  draw_circle(C,249,Color("#b27e4e"))
  draw_circle(C,243,Color("#dfb37d"))
  draw_arc(C,240,0,TAU,96,Color("#bc8b5a"),3,true)
 if phase==3:
  draw_oven_scene()
 elif phase==5:
  draw_pack_scene()
 else:
  draw_pizza(1.0)
  if phase==0: draw_image("roller",Rect2(roller_at-Vector2(150,45),Vector2(300,90)))
  if phase==4 and dragging:
   for i in range(1,cut_path.size()): draw_line(cut_path[i-1],cut_path[i],Color("#fdf4db"),5,true)
   draw_image("cutter",Rect2(last-Vector2(55,45),Vector2(110,80)))
 if phase==2 and dragging_tool and not inside(last):
  draw_image(selected,Rect2(last-Vector2(32,32),Vector2(64,64)))

func draw_oven_scene() -> void:
 # Independent oven housing, cavity, rack, glass door and animated pizza peel.
 draw_style_box(panel_style(Color("#494140"),Color("#2c2421"),24),Rect2(275,140,590,408))
 draw_style_box(panel_style(Color("#b9a99a"),Color("#6c5646"),20),Rect2(290,150,560,386))
 draw_style_box(panel_style(Color("#352827"),Color("#806049"),14),Rect2(315,207,510,272))
 for j in range(8):
  draw_line(Vector2(333,438+j*4),Vector2(808,438+j*4),Color("#8d7c6d"),2,true)
 for j in range(3):
  draw_style_box(panel_style(Color("#f0ba62") if baking else Color("#49362f"),Color("#6a5042"),5),Rect2(360+j*145,218,120,10))
 if baking:
  draw_rect(Rect2(328,230,484,204),Color(1,.43,.12,.15+.07*sin(tick*5)))
 var load_amount=0.0
 if oven_state==1: load_amount=smoothstep(0.0,1.0,oven_motion)
 elif oven_state==2 or oven_state==3: load_amount=1.0
 elif oven_state==4: load_amount=1.0-smoothstep(0.0,1.0,oven_motion)
 var pizza_shift=Vector2(0,116-146*load_amount)
 var pizza_scale=lerpf(.65,.46,load_amount)
 if oven_state!=3:
  draw_style_box(panel_style(Color("#b98b58"),Color("#725035"),12),Rect2(C.x-150,C.y+120-146*load_amount,300,28))
  draw_style_box(panel_style(Color("#ae7544"),Color("#70452b"),12),Rect2(C.x+135,C.y+123-146*load_amount,182,22))
 draw_pizza(pizza_scale,pizza_shift)
 if oven_state==3:
  draw_style_box(panel_style(Color(0.19,0.10,0.08,.28),Color("#65463c"),13),Rect2(315,207,510,272))
  draw_line(Vector2(382,240),Vector2(454,240),Color(1,1,1,.18),5,true)
  for j in range(7):
   var t=fposmod(tick*.55+j*.14,1.0)
   draw_circle(Vector2(400+j*54+sin(tick*3+j)*8,300-t*65),6+t*12,Color(1,.85,.56,(1-t)*.22))
 else:
  draw_style_box(panel_style(Color("#73665b"),Color("#3d302b"),12),Rect2(315,478,510,40))
 draw_style_box(panel_style(Color("#222b27"),Color("#6f6556"),8),Rect2(468,160,204,34))
 draw_string(ThemeDB.fallback_font,Vector2(514,184),str(roundi(heat*100))+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("#d9f4aa"))
 var zone=oven_bounds()
 draw_style_box(panel_style(Color("#4a372c"),Color("#9b7651"),10),Rect2(310,558,520,24))
 draw_rect(Rect2(310+520*zone.x,562,520*(zone.y-zone.x),16),Color("#80c96b"))
 draw_circle(Vector2(310+520*heat,570),12,Color("#fff3c9"))

func draw_pack_scene() -> void:
 var centre=Vector2(570,366)
 draw_style_box(panel_style(Color("#b5844e"),Color("#7d5433"),17),Rect2(315,296,510,275))
 draw_style_box(panel_style(Color("#f3dfb5"),Color("#b28755"),12),Rect2(331,306,478,244))
 var motion=smoothstep(0.0,1.0,pack_time/.65) if packing else 0.0
 var loaded=1.0 if pack_stage>=1 else motion
 var closure=1.0 if pack_stage>=2 else (motion if pack_stage==1 else 0.0)
 var lid_h=lerpf(150.0,264.0,closure)
 var lid_y=lerpf(143.0,295.0,closure)
 if closure<.99:
  draw_style_box(panel_style(Color("#e5c38e"),Color("#9e703f"),15),Rect2(315,lid_y,510,lid_h))
 draw_pizza(.68,Vector2(0,lerpf(-112.0,62.0,loaded)))
 if closure>.01:
  draw_style_box(panel_style(Color("#e6c697"),Color("#97693c"),15),Rect2(315,lid_y,510,lid_h))
  draw_style_box(panel_style(Color("#fff0d2"),Color("#ba915b"),12),Rect2(400,lid_y+lid_h*.27,340,86))
  draw_string(ThemeDB.fallback_font,Vector2(440,lid_y+lid_h*.27+53),"PIZZAVITO",HORIZONTAL_ALIGNMENT_LEFT,-1,39,Color("#34634d"))
  draw_line(Vector2(335,lid_y+lid_h-17),Vector2(805,lid_y+lid_h-17),Color("#bf945e"),4,true)
 if pack_stage>=3 or (pack_stage==2 and packing):
  var seal_scale=1.0 if pack_stage>=3 else motion
  draw_circle(Vector2(570,548),32*seal_scale,Color("#367851"))
  draw_arc(Vector2(570,548),26*seal_scale,0,TAU,40,Color("#f9e3a3"),3,true)
  draw_string(ThemeDB.fallback_font,Vector2(559,556),"✓",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color.WHITE)
func draw_pizza(scale_factor: float,shift: Vector2=Vector2.ZERO) -> void:
 var actual = scale_factor*(0.57+0.43*dough_progress if phase==0 else 1.0)
 var shadow_shift = shift+Vector2(0,14)
 layer(actual,Color(0.27,0.18,0.12,0.23),shadow_shift)
 var baked_mix = heat if phase>=3 else 0.0
 layer(actual,Color("#b87b47").lerp(Color("#a56332"),baked_mix),shift+Vector2(0,7))
 layer(actual,Color("#e5b875").lerp(Color("#cc8b45"),baked_mix),shift)
 layer(actual*.95,Color("#f5d597").lerp(Color("#efbb68"),baked_mix),shift)
 layer(actual*.82,Color("#f8e0a9").lerp(Color("#ebbb71"),baked_mix),shift)
 # Crust micro-details and a deliberately soft hand-painted edge.
 for i in range(58):
  var a = float(i)*2.39996
  var r = radius_for(a)*actual*(.86+.07*float(i%4)/3.0)
  var p = C+shift+Vector2(cos(a),sin(a))*r
  draw_circle(p,2.0+float(i%4),Color(0.58,0.31,0.13,0.21+baked_mix*.15))
 if phase>=1:
  var col = Color("#b9422d") if sauce_kind=="sauce" else Color("#e9d3a5")
  if phase>1 or sauce_cells.size()>=sauce_target():
   layer(actual*.79,col,shift)
   layer(actual*.76,col.lightened(.08),shift)
   for i in range(26):
    var a = i*2.399
    var rr = sqrt(float(i)/26.0)*radius_for(a)*actual*.70
    draw_circle(C+shift+Vector2(cos(a),sin(a))*rr,2.8+float(i%3),col.darkened(.12))
  else:
   for dab in sauce_dabs:
    draw_circle(C+shift+(dab-C)*scale_factor,22*scale_factor,col)
 if phase>=2:
  if phase==2 and not free and recipe>=5 and not ready_for_next():
   var target = target_position()
   draw_circle(target,30,Color(1,0.94,0.64,.26))
   draw_arc(target,30,0,TAU,48,Color("#fff7be"),4,true)
   draw_circle(target,5,Color("#fff7be"))
  for i in range(toppings.size()):
   var item = toppings[i]
   var p: Vector2 = item["p"]
   var offset = (p-C)*scale_factor+shift
   if phase>=5:
    var a = (p-C).angle()
    var sector = floorf(fposmod(a,TAU)/(TAU/float(required_slices()*2)))
    var mid = (sector+.5)*TAU/float(required_slices()*2)
    offset+=Vector2(cos(mid),sin(mid))*6
   var side = 65.0*scale_factor
   var food_key = str(item["key"])
   var area = Rect2(C+offset-Vector2.ONE*side*.5,Vector2.ONE*side)
   draw_circle(C+offset+Vector2(2,4)*scale_factor,side*.30,Color(0.25,0.12,0.04,0.20))
   var age = clampf((tick-float(item.get("born",-10.0)))*5.0,0,1)
   var bounce = sin(age*PI)*10.0
   area.position.y-=bounce
   draw_image(food_key,area)
   if age<1.0:
    draw_arc(C+offset,side*.35+age*24,0,TAU,24,Color(1,.94,.68,1-age),3,true)
 if phase==4:
  if cut_hint and cuts.size()<required_slices():
   var a = float(cuts.size())*PI/float(required_slices())
   var v = Vector2(cos(a),sin(a))*R*.92
   draw_line(C-v,C+v,Color("#fff5d2"),5.0,true)
  for a in cuts:
   var dir = Vector2(cos(a),sin(a))
   var left_edge = C-dir*radius_for(a+PI)*.99
   var right_edge = C+dir*radius_for(a)*.99
   draw_line(left_edge,right_edge,Color("#713b24"),8.0,true)
   draw_line(left_edge+Vector2(0,3),right_edge+Vector2(0,3),Color("#f6d49b"),2.0,true)
 if phase==5:
  for i in range(required_slices()*2):
   var a = float(i)*TAU/float(required_slices()*2)
   var dir = Vector2(cos(a),sin(a))
   draw_line(C+shift,C+shift+dir*radius_for(a)*actual,Color("#a56d45"),5.0,true)

func _input(event: InputEvent) -> void:
 if screen!="cook": return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  var p = event.position
  if event.pressed:
   last=p
   stroke_start=p
   cut_path.clear()
   cut_path.append(p)
   if phase==2:
    for key in tray_rects:
     if Rect2(tray_rects[key]).has_point(p):
      selected=str(key)
      dragging_tool=true
      update_status()
      return
   if phase<=4 and phase!=3 and inside(p,1.40):
    dragging=true
    dragging_tool=phase==2
    if phase==1: apply_sauce(p)
    if phase==2: add_topping(p)
   return
  else:
   if phase==2 and dragging_tool and inside(p,.94) and not dragging: add_topping(p)
   if phase==4 and dragging: apply_cut(stroke_start,p)
   cut_path.clear()
   dragging=false
   dragging_tool=false
   queue_redraw()
 elif event is InputEventMouseMotion and (dragging or dragging_tool):
  var p = event.position
  var distance = p.distance_to(last)
  if phase==0 and inside(p,1.08):
   var effort = 420.0 if free else 420.0+minf(float(recipe)*12.0,300.0)
   dough_progress=minf(1.0,dough_progress+minf(distance,95.0)/effort)
   roller_at=roller_at.lerp(p,.65)
  elif phase==1:
   for i in range(1,maxi(1,ceili(distance/18.0))+1):
    apply_sauce(last.lerp(p,float(i)/maxi(1,ceili(distance/18.0))))
  elif phase==2 and inside(p,.94) and distance>16 and (free or recipe<5): add_topping(p)
  elif phase==4 and cut_path.size()<100: cut_path.append(p)
  last=p
  update_status()

func apply_sauce(p: Vector2) -> void:
 if not inside(p,.98): return
 var changed = false
 for cell in sauce_goal_cells:
  if sauce_cells.has(cell): continue
  var center = C+Vector2(cell)*34.0
  if center.distance_to(p)<56.0:
   sauce_cells[cell]=true
   sauce_dabs.append(center)
   changed = true
 if changed:
  click()
  update_status()

func add_topping(p: Vector2) -> void:
 if not inside(p,.94) or toppings.size()>=64: return
 if not inside(p,.77):
  p = C+(p-C).normalized()*radius_for((p-C).angle())*.76
 if not free and topping_count(selected)>=ingredient_quota(): return
 for item in toppings:
  var other: Vector2 = item["p"]
  if other.distance_to(p)<29: return
 if not free and recipe>=5:
  var target = target_position()
  var tolerance = maxf(45.0,88.0-float(recipe)*.8)
  if p.distance_to(target)>tolerance: return
  action_total+=1
  if p.distance_to(target)<tolerance*.6: action_accuracy+=1
  p=target
 toppings.append({"key":selected,"p":p,"born":tick})
 if not free and topping_count(selected)>=ingredient_quota():
  for key in book[recipe]["ingredients"]:
   if topping_count(str(key))<ingredient_quota():
    selected = str(key)
    break
 click()
 update_status()

func apply_cut(a: Vector2,b: Vector2) -> void:
 if a.distance_to(b)<radius_for((b-a).angle())*.40: return
 var segment = b-a
 var t = clampf((C-a).dot(segment)/maxf(segment.length_squared(),1),0,1)
 if (a+segment*t).distance_to(C)>R*.65: return
 var angle = fposmod((b-a).angle(),PI)
 var target = float(cuts.size())*PI/float(required_slices())
 var gap = absf(angle-target)
 var error = minf(gap,PI-gap)
 var tolerance = .85 if free or recipe<3 else maxf(.22,.85-float(recipe)*.013)
 if error>tolerance: return
 cut_error+=error
 cuts.append(target)
 click()
 update_status()

func _process(delta: float) -> void:
 tick+=delta
 if screen=="gallery" and is_instance_valid(preview_pivot): preview_pivot.rotate_y(delta*.45)
 if screen=="cook":
  if phase==3 and (oven_state==1 or oven_state==4):
   oven_motion=minf(1.0,oven_motion+delta*1.4)
   if oven_motion>=1.0:
    if oven_state==1: oven_state=2
    else:
     oven_state=5
     baked=true
    update_status()
  if baking:
   heat=minf(1.0,heat+delta*(.10 if free else .10+minf(float(recipe)*.002,.10)))
   if heat>=1.0: stop_bake()
   update_status()
  if phase==5:
   pack_anim=minf(1.0,pack_anim+delta)
   if packing:
    pack_time+=delta
    if pack_time>=0.65:
     packing=false
     pack_stage=mini(3,pack_stage+1)
     pack_time=0.0
     update_status()
  if phase==2 or phase==3 or phase==5: queue_redraw()

func setup_audio() -> void:
 audio=AudioStreamPlayer.new()
 audio.volume_db=-19.0
 add_child(audio)
 pop=AudioStreamWAV.new()
 pop.format=AudioStreamWAV.FORMAT_16_BITS
 pop.mix_rate=22050
 var bytes=PackedByteArray()
 bytes.resize(1400*2)
 var rng=RandomNumberGenerator.new()
 rng.seed=718
 for i in range(1400):
  bytes.encode_s16(i*2,int(rng.randf_range(-1,1)*exp(-float(i)/200)*6500))
 pop.data=bytes

func click() -> void:
 if is_instance_valid(audio):
  audio.stream=pop
  audio.play()

func gallery_ui() -> void:
 header(tr3("Ingredient gallery • real 3D","معرض المكونات ثلاثية الأبعاد","Galeria 3D de ingredientes"),"home")
 panel(ui,Rect2(42,125,455,550),Color("#fff1d7"),Color("#c99360"))
 panel(ui,Rect2(515,125,722,550),Color("#fff1d7"),Color("#c99360"))
 for i in range(FOODS.size()):
  var key = FOODS[i]
  var b = button(ui,"",Rect2(58+(i%3)*144,145+int(i/3)*168,132,151),func(): show_model(key))
  image_node(b,key,Rect2(11,4,110,106))
  label(b,food_name(key),Rect2(4,111,124,32),19)
 if DisplayServer.get_name()=="headless":
  label(ui,tr3("3D preview","معاينة ثلاثية الأبعاد","Prévia 3D"),Rect2(550,220,660,100),36)
  return
 model_view=SubViewportContainer.new()
 model_view.position=Vector2(535,148)
 model_view.size=Vector2(681,500)
 model_view.stretch=true
 model_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
 ui.add_child(model_view)
 preview_world=SubViewport.new()
 preview_world.size=Vector2i(681,500)
 preview_world.own_world_3d=true
 preview_world.transparent_bg=true
 model_view.add_child(preview_world)
 var camera=Camera3D.new()
 camera.position=Vector3(2.2,1.65,2.5)
 preview_world.add_child(camera)
 camera.look_at(Vector3.ZERO)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=2.5
 camera.current=true
 var light=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-45,-35,0)
 light.light_energy=.85
 preview_world.add_child(light)
 var env=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE
 env.environment.ambient_light_energy=.5
 preview_world.add_child(env)
 preview_pivot=Node3D.new()
 preview_world.add_child(preview_pivot)
 show_model("tomato")

func show_model(key: String) -> void:
 if not is_instance_valid(preview_pivot): return
 preview_pivot.rotation = Vector3.ZERO
 preview_pivot.scale = Vector3.ONE
 for child in preview_pivot.get_children():
  preview_pivot.remove_child(child)
  child.queue_free()
 if not manifest.has(key):
  var fallback = MeshInstance3D.new()
  var mesh = QuadMesh.new()
  mesh.size = Vector2(1.65,1.65)
  fallback.mesh = mesh
  var material = StandardMaterial3D.new()
  material.albedo_texture = tex[key]
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  material.cull_mode = BaseMaterial3D.CULL_DISABLED
  material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
  fallback.material_override = material
  preview_pivot.add_child(fallback)
  return
 var entry: Dictionary=manifest[key]
 var resource=load(str(entry["path"]))
 if not resource is PackedScene: return
 var node=resource.instantiate()
 if not node is Node3D:
  node.free()
  return
 preview_pivot.add_child(node)
 var bounds=AABB()
 var have=false
 for child in node.find_children("*","MeshInstance3D",true,false):
  var m=child as MeshInstance3D
  if m.mesh==null: continue
  var b=preview_pivot.global_transform.affine_inverse()*m.global_transform*m.get_aabb()
  bounds=bounds.merge(b) if have else b
  have=true
 if have:
  var longest=maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
  if longest>0.001:
   node.position-=bounds.get_center()
   preview_pivot.scale=Vector3.ONE*(1.7/longest)

func smoke() -> void:
 scores.clear()
 unlocked=0
 assert(book.size()==50)
 start_recipe(1,false)
 assert(screen=="home")
 for i in range(book.size()): assert(ResourceLoader.exists(ART+"recipe_"+str(i)+".svg"))
 for item in book:
  assert(item["ingredients"].size()>=3)
  for key in item["ingredients"]: assert(tex.has(key))
 for key in ["tomato","pizza","oven","counter"]:
  assert(manifest.has(key))
  assert(ResourceLoader.exists(str(manifest[key]["path"])))
 start_recipe(0,false)
 dough_progress=1.0
 advance()
 assert(phase==1)
 for i in range(sauce_target()): sauce_cells[Vector2i(i,0)]=true
 advance()
 assert(phase==2)
 for key in book[recipe]["ingredients"]:
  for i in range(ingredient_quota()):
   toppings.append({"key":key,"p":C+Vector2(i*10,0)})
 advance()
 assert(phase==3)
 oven_action()
 assert(oven_state==1)
 _process(1.0)
 assert(oven_state==2)
 oven_button.pressed.emit()
 assert(baking)
 heat=.75
 oven_button.pressed.emit()
 assert(not baking and oven_state==4)
 _process(1.0)
 assert(baked and oven_state==5)
 advance()
 assert(phase==4)
 for i in range(required_slices()): cuts.append(float(i)*PI/required_slices())
 advance()
 assert(phase==5)
 for step in range(3):
  advance()
  assert(packing)
  _process(1.0)
  assert(pack_stage==step+1)
 advance()
 assert(screen=="result")
 assert(unlocked>=1)
 var before = recipe
 start_recipe(book.size()-1,false)
 assert(recipe==before)
 unlocked=5
 start_recipe(5,false)
 assert(screen=="market")
 for key in book[recipe]["ingredients"]: market_pick(str(key))
 assert(shopping.size()==book[recipe]["ingredients"].size())
 go("cook")
 phase=2
 toppings.clear()
 add_topping(target_position())
 assert(toppings.size()==1)
 go("book")
 assert(ui.get_child_count()>0)
 go("kitchens")
 go("settings")
 go("gallery")
 print("PIZZAVITO_SMOKE_OK")
 get_tree().quit()

func ingredient_quota() -> int:
 if free: return 3
 return 2 if recipe<3 else (3 if recipe<10 else (4 if recipe<30 else 5))

func build_sauce_grid() -> void:
 sauce_goal_cells.clear()
 for x in range(-6,7):
  for y in range(-6,7):
   var cell = Vector2i(x,y)
   if inside(C+Vector2(cell)*34.0,.73): sauce_goal_cells.append(cell)

func assist_cut() -> void:
 if phase!=4 or cuts.size()>=required_slices(): return
 cuts.append(float(cuts.size())*PI/float(required_slices()))
 click()
 update_status()

func assist_step() -> void:
 if phase==0:
  dough_progress = minf(1.0,dough_progress+.34)
 elif phase==1:
  for cell in sauce_goal_cells:
   if not sauce_cells.has(cell):
    apply_sauce(C+Vector2(cell)*34.0)
    break
 elif phase==2:
  if not free and recipe>=5:
   add_topping(target_position())
   return
  for i in range(36):
   var a = float(i)*2.39996
   var radius = sqrt(float(i+1)/36.0)*radius_for(a)*.74
   var p = C+Vector2(cos(a),sin(a))*radius
   var before = toppings.size()
   add_topping(p)
   if toppings.size()>before: break
 update_status()

func cycle_shape() -> void:
 if not free or phase!=0: return
 var idx = (shape_options.find(shape_kind)+1)%shape_options.size()
 shape_kind=shape_options[idx]
 dough_progress=0
 build_sauce_grid()
 rebuild_ui()

func target_position() -> Vector2:
 var idx = toppings.size()
 var a = float(idx)*2.399963
 var radius = radius_for(a)*(.30+.43*sqrt(float(idx+1)/float(maxi(1,topping_target()))))
 return C+Vector2(cos(a),sin(a))*radius

func market_ui() -> void:
 header(tr3("Market • fill the order","السوق • اختر مكونات الطلب","Mercado • complete o pedido"),"home")
 panel(ui,Rect2(35,112,818,557),Color("#f8e4bf"),Color("#bd8855"))
 panel(ui,Rect2(870,112,370,557),Color("#fff6df"),Color("#b18459"))
 label(ui,tr3("Choose the ingredients","اختر المكونات الصحيحة","Escolha os ingredientes"),Rect2(56,121,776,56),31)
 var required: Array = book[recipe]["ingredients"]
 for i in range(FOODS.size()):
  var key = FOODS[i]
  var card = button(ui,"",Rect2(58+(i%3)*260,184+int(i/3)*152,245,140),func(): market_pick(key),false)
  var img = image_node(card,key,Rect2(14,12,112,112))
  if actual_previews.has(key): img.texture = actual_previews[key]
  label(card,food_name(key),Rect2(127,20,110,64),20)
  if shopping.has(key):
   label(card,"✓",Rect2(153,82,65,45),33,Color("#2d8550"))
   card.disabled=true
 label(ui,tr3("Shopping list","قائمة التسوق","Lista de compras"),Rect2(885,126,340,50),30)
 for i in range(required.size()):
  var key = str(required[i])
  var y = 195+i*78
  image_node(ui,key,Rect2(891,y,70,70))
  label(ui,food_name(key)+(" ✓" if shopping.has(key) else ""),Rect2(974,y,238,65),23)
 label(ui,market_feedback,Rect2(885,510,340,66),22,Color("#79523c"))
 var next = button(ui,tr3("To the kitchen","إلى المطبخ","Ir à cozinha"),Rect2(888,588,335,64),func(): go("cook"),true,25)
 next.disabled = shopping.size()!=required.size()

func market_pick(key: String) -> void:
 if key in book[recipe]["ingredients"]:
  shopping[key]=true
  market_feedback=tr3("Great choice!","اختيار صحيح!","Boa escolha!")
 else:
  market_feedback=tr3("Try an item on the list","جرّب مكوناً من القائمة","Tente um item da lista")
 click()
 rebuild_ui()
