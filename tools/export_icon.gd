extends SceneTree
func _initialize() -> void:
 var im = Image.load_from_file("res://icon.svg")
 if im==null or im.is_empty():
  quit(1)
  return
 im.resize(192,192,Image.INTERPOLATE_LANCZOS)
 quit(0 if im.save_png("res://assets/art/launcher.png")==OK else 1)
