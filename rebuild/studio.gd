extends Control
# Rebuilt touch-first 2.5D cooking studio. Old 3D prototype is retained in git history.
const C = Vector2(620,375)
const R = 205.0
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

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 build_recipes()
 var cfg = ConfigFile.new()
 if cfg.load("user://studio.cfg")==OK:
  lang = clampi(int(cfg.get_value("studio","lang",0)),0,2)
  kitchen = clampi(int(cfg.get_value("studio","kitchen",0)),0,3)
  scores = cfg.get_value("studio","scores",{})
 for key in KITCHENS+FOODS+["sauce","white","hero","roller","oven","box","cutter"]:
  tex[key] = load(ART+str(key)+".svg")
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
  b.add_theme_stylebox_override(state,panel_style(color,edge,18))
 b.add_theme_color_override("font_color",Color("#fff8df") if accent else Color("#4b3a2f"))
 b.add_theme_color_override("font_hover_color",Color.WHITE if accent else Color("#4b3a2f"))
 b.add_theme_color_override("font_pressed_color",Color.WHITE if accent else Color("#4b3a2f"))
 b.pressed.connect(func():
  click()
  action.call())
 parent.add_child(b)
 return b

func image_node(parent: Control,key: String,area: Rect2) -> TextureRect:
 var v = TextureRect.new()
 v.position = area.position
 v.size = area.size
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
  var card = button(ui,"",area,func(): start_recipe(index,false),false)
  var rec = book[i]
  image_node(card,"hero",Rect2(13,17,150,150))
  label(card,str(rec["names"][lang]),Rect2(169,13,195,72),25,Color("#355b4a"),true)
  var stars = int(scores.get(str(i),0))
  label(card,"★".repeat(stars)+"☆".repeat(3-stars),Rect2(169,83,195,42),25,Color("#d08b35"))
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
 bake_quality = 0
 finish_score = 0
 pack_anim = 0.0
 roller_at = C
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
 panel(ui,Rect2(24,124,238,478),Color("#fff1d9"),Color("#c68e5c"))
 label(ui,tr3("YOUR ORDER","طلبك","SEU PEDIDO"),Rect2(35,136,216,40),23,Color("#a65338"))
 label(ui,tr3("Free kitchen","المطبخ الحر","Cozinha livre") if free else str(book[recipe]["names"][lang]),Rect2(34,177,218,66),28)
 image_node(ui,"hero",Rect2(62,246,160,160))
 label(ui,shape_label(shape_kind)+"\n"+food_name(sauce_kind),Rect2(36,412,214,75),24)
 var order_items: Array = book[recipe]["ingredients"] if not free else []
 for i in range(mini(order_items.size(),4)):
  image_node(ui,str(order_items[i]),Rect2(37+i*53,490,51,51))
 panel(ui,Rect2(980,124,276,478),Color("#fff1d9"),Color("#c68e5c"))
 status = label(ui,"",Rect2(995,140,246,120),27)
 progress_label = label(ui,"",Rect2(995,527,246,58),23,Color("#a85a3d"))
 match phase:
  0:
   image_node(ui,"roller",Rect2(999,270,235,80))
   label(ui,tr3("Drag across the dough","مرّر فوق العجين","Deslize sobre a massa"),Rect2(1000,365,236,112),25)
  1:
   image_node(ui,sauce_kind,Rect2(1040,264,156,156))
   if free:
    button(ui,tr3("Switch sauce","بدّل الصلصة","Trocar molho"),Rect2(997,443,242,64),func(): switch_sauce(),false,22)
  2: build_tray()
  3:
   image_node(ui,"oven",Rect2(1013,269,213,177))
   button(ui,tr3("Start oven","شغّل الفرن","Ligar forno"),Rect2(996,447,244,62),start_bake,true,25)
  4:
   image_node(ui,"cutter",Rect2(1015,271,208,155))
   button(ui,tr3("Show guide","دليل القطع","Mostrar guia"),Rect2(996,447,244,62),func(): cut_hint = not cut_hint,false,23)
  5:
   image_node(ui,"box",Rect2(1010,268,216,180))
 panel(ui,Rect2(20,620,1240,82),Color("#fff1d9"),Color("#c48b59"))
 button(ui,tr3("Restart","إعادة","Reiniciar"),Rect2(33,632,175,58),func(): start_recipe(recipe,free),false,24)
 if phase==2:
  button(ui,tr3("Undo","تراجع","Desfazer"),Rect2(224,632,160,58),undo_topping,false,23)
 advance_button = button(ui,tr3("Next  ›","التالي  ‹","Próximo  ›"),Rect2(938,631,308,60),advance,true,29)
 update_status()

func build_tray() -> void:
 var list: Array = FOODS if free else book[recipe]["ingredients"]
 for i in range(list.size()):
  var key = str(list[i])
  var x = 993+(i%3)*85
  var y = 260+int(i/3)*84
  var area = Rect2(x,y,80,79)
  var b = button(ui,"",area,func(): select_food(key),false)
  image_node(b,key,Rect2(7,1,66,59))
  label(b,food_name(key),Rect2(1,57,78,18),14,Color("#594738"))
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
 return 24 if shape_kind=="mini" else 38

func topping_target() -> int:
 return 10 if free else int(book[recipe]["portion"])*book[recipe]["ingredients"].size()

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
  total += mini(topping_count(str(key)),int(book[recipe]["portion"]))
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
  3:
   status.text = tr3("Stop in the green zone","أوقف الفرن في المنطقة الخضراء","Pare na zona verde")
   progress_label.text = str(roundi(heat*100))+"%"
  4:
   status.text = tr3("Swipe across the centre","اسحب عبر المنتصف","Deslize pelo centro")
   progress_label.text = str(cuts.size())+" / "+str(required_slices())
  5:
   status.text = tr3("Ready to serve!","جاهزة للتقديم!","Pronta para servir!")
   progress_label.text = ""
 if is_instance_valid(advance_button):
  advance_button.disabled = not ready_for_next()
  if phase==3 and baking:
   advance_button.disabled = false
   advance_button.text = tr3("Stop oven","أوقف الفرن","Parar forno")
  elif phase==3:
   advance_button.text = tr3("Next  ›","التالي  ‹","Próximo  ›")
  elif phase==5:
   advance_button.text = tr3("Serve pizza","قدّم البيتزا","Servir pizza")
 queue_redraw()

func start_bake() -> void:
 if baking or baked: return
 heat = 0.0
 baking = true
 update_status()

func stop_bake() -> void:
 baking = false
 bake_quality = 3 if heat>=0.65 and heat<=0.85 else (2 if heat>=0.45 and heat<=0.96 else 1)
 baked = true
 click()
 update_status()

func advance() -> void:
 if phase==3 and baking:
  stop_bake()
  return
 if not ready_for_next(): return
 if phase==5:
  finish_score = maxi(1,mini(3,bake_quality))
  if not free:
   scores[str(recipe)] = maxi(int(scores.get(str(recipe),0)),finish_score)
  persist()
  go("result")
  return
 phase+=1
 if phase==5: pack_anim=0.0
 click()
 rebuild_ui()

func result_ui() -> void:
 panel(ui,Rect2(255,72,770,576),Color("#fff0d7"),Color("#c99360"))
 label(ui,tr3("Pizza served!","تم تقديم البيتزا!","Pizza servida!"),Rect2(280,88,720,75),48,Color("#3c7256"))
 image_node(ui,"hero",Rect2(495,177,290,290))
 label(ui,"★".repeat(finish_score)+"☆".repeat(3-finish_score),Rect2(300,465,680,60),48,Color("#d79432"))
 button(ui,tr3("Recipe book","دفتر الوصفات","Receitas"),Rect2(295,552,330,67),func(): go("book"),false,26)
 button(ui,tr3("Next pizza","البيتزا التالية","Próxima pizza"),Rect2(652,552,330,67),func(): start_recipe((recipe+1)%book.size(),false),true,26)

func radius_for(a: float) -> float:
 match shape_kind:
  "heart":
   return R*(1.0-0.19*sin(a)-0.12*cos(2*a)+0.08*cos(4*a))
  "square": return R*0.76/maxf(absf(cos(a)),absf(sin(a)))
  "star": return R*(0.83+0.17*cos(5*a))
  "mini": return R*0.73
  _: return R

func inside(p: Vector2,factor: float=1.0) -> bool:
 var q = p-C
 return q.length()<=radius_for(q.angle())*factor

func outline(scale_factor: float, shift: Vector2=Vector2.ZERO, start: float=0.0, sweep: float=TAU) -> PackedVector2Array:
 var pts = PackedVector2Array()
 if sweep<TAU-0.01: pts.append(C+shift)
 var count = maxi(10,roundi(100.0*sweep/TAU))
 for i in range(count+1):
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
 draw_style_box(panel_style(Color("#d5a573"),Color("#9c6a47"),38),Rect2(277,126,688,476))
 draw_style_box(panel_style(Color("#f7dfb6"),Color("#e9c79b"),32),Rect2(291,140,660,447))
 for i in range(12):
  var y = 157+i*35
  draw_line(Vector2(308,y),Vector2(934,y+3),Color(0.63,0.43,0.25,0.09),2.0,true)
 if phase==3:
  draw_image("oven",Rect2(305,120,630,494))
  draw_pizza(0.69,Vector2(0,34))
  var bar = Rect2(424,558,392,22)
  draw_style_box(panel_style(Color("#573b30"),Color("#704e37"),10),bar)
  draw_rect(Rect2(424+392*.65,562,392*.20,14),Color("#9ac77b"))
  draw_circle(Vector2(424+392*heat,569),13,Color("#ffedbe"))
  if baking:
   for i in range(6):
    var t = fposmod(tick*0.6+i*.17,1.0)
    draw_circle(Vector2(480+i*55+sin(tick*2+i)*12,280-t*90),9+t*13,Color(1,0.87,0.63,(1-t)*.30))
 elif phase==5:
  draw_image("box",Rect2(315,120,610,478))
  draw_pizza(0.82,Vector2(0,12))
  if pack_anim>0:
   for i in range(14):
    var a = float(i)*2.399
    var rr = 210+sin(tick*2+i)*16
    draw_circle(C+Vector2(cos(a),sin(a))*rr,4.0+float(i%3),Color("#f5cb65"))
 else:
  draw_pizza(1.0)
  if phase==0: draw_image("roller",Rect2(roller_at-Vector2(150,45),Vector2(300,90)))
  if phase==4 and dragging:
   draw_image("cutter",Rect2(last-Vector2(55,45),Vector2(110,80)))
 if phase==2 and dragging_tool and not inside(last):
  draw_image(selected,Rect2(last-Vector2(32,32),Vector2(64,64)))

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
  for i in range(toppings.size()):
   var item = toppings[i]
   var p: Vector2 = item["p"]
   var offset = (p-C)*scale_factor+shift
   if phase>=5:
    var a = (p-C).angle()
    var sector = floorf(fposmod(a,TAU)/(TAU/float(required_slices()*2)))
    var mid = (sector+.5)*TAU/float(required_slices()*2)
    offset+=Vector2(cos(mid),sin(mid))*6
   var side = 54.0*scale_factor
   draw_image(str(item["key"]),Rect2(C+offset-Vector2.ONE*side*.5,Vector2.ONE*side),Color(1,1,1,1))
 if phase==4:
  if cut_hint and cuts.size()<required_slices():
   var a = float(cuts.size())*PI/float(required_slices())
   var v = Vector2(cos(a),sin(a))*R*.92
   draw_line(C-v,C+v,Color("#fff5d2"),5.0,true)
  for a in cuts:
   var dir = Vector2(cos(a),sin(a))
   draw_line(C-dir*radius_for(a)*.99,C+dir*radius_for(a+PI)*.99,Color("#8f5234"),5.0,true)
   draw_line(C-dir*radius_for(a)*.97+Vector2(0,2),C+dir*radius_for(a+PI)*.97+Vector2(0,2),Color("#f2c97d"),2.0,true)
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
   if phase==2:
    for key in tray_rects:
     if Rect2(tray_rects[key]).has_point(p):
      selected=str(key)
      dragging_tool=true
      update_status()
      return
   if phase<=4 and phase!=3 and inside(p,1.13):
    dragging=true
    dragging_tool=phase==2
    if phase==1: apply_sauce(p)
    if phase==2: add_topping(p)
   return
  else:
   if phase==2 and dragging_tool and inside(p,.78): add_topping(p)
   if phase==4 and dragging: apply_cut(stroke_start,p)
   dragging=false
   dragging_tool=false
   queue_redraw()
 elif event is InputEventMouseMotion and (dragging or dragging_tool):
  var p = event.position
  var distance = p.distance_to(last)
  if phase==0 and inside(p,1.08):
   dough_progress=minf(1.0,dough_progress+distance/1150.0)
   roller_at=p
  elif phase==1 and inside(p,.77): apply_sauce(p)
  elif phase==2 and inside(p,.76) and distance>8: add_topping(p)
  last=p
  update_status()

func apply_sauce(p: Vector2) -> void:
 if not inside(p,.76): return
 var cell = Vector2i(floori((p.x-C.x)/35),floori((p.y-C.y)/35))
 if sauce_cells.has(cell): return
 sauce_cells[cell]=true
 sauce_dabs.append(p)
 click()
 update_status()

func add_topping(p: Vector2) -> void:
 if not inside(p,.76) or toppings.size()>=64: return
 if not free and topping_count(selected)>=int(book[recipe]["portion"])+2: return
 for item in toppings:
  var other: Vector2 = item["p"]
  if other.distance_to(p)<30: return
 toppings.append({"key":selected,"p":p})
 click()
 update_status()

func apply_cut(a: Vector2,b: Vector2) -> void:
 if a.distance_to(b)<R*0.85: return
 var mid = (a+b)*.5
 if mid.distance_to(C)>R*.33: return
 var angle = fposmod((b-a).angle(),PI)
 var target = float(cuts.size())*PI/float(required_slices())
 var gap = absf(angle-target)
 if minf(gap,PI-gap)>0.55: return
 cuts.append(target)
 click()
 update_status()

func _process(delta: float) -> void:
 tick+=delta
 if screen=="cook":
  if baking:
   heat=minf(1.0,heat+delta*.11)
   if heat>=1.0: stop_bake()
   update_status()
  if phase==5: pack_anim=minf(1.0,pack_anim+delta)
  if phase==3 or phase==5: queue_redraw()

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
 for child in preview_pivot.get_children():
  preview_pivot.remove_child(child)
  child.queue_free()
 if not manifest.has(key):
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
 assert(book.size()==50)
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
  for i in range(int(book[recipe]["portion"])):
   toppings.append({"key":key,"p":C+Vector2(i*10,0)})
 advance()
 assert(phase==3)
 heat=.76
 stop_bake()
 advance()
 assert(phase==4)
 for i in range(required_slices()): cuts.append(float(i)*PI/required_slices())
 advance()
 assert(phase==5)
 advance()
 assert(screen=="result")
 go("book")
 assert(ui.get_child_count()>0)
 go("kitchens")
 go("settings")
 go("gallery")
 print("PIZZAVITO_SMOKE_OK")
 get_tree().quit()
