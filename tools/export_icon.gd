extends SceneTree
func _initialize() -> void:
 var im = Image.load_from_file("res://assets/art/approved_icon.png")
 if im==null or im.is_empty() or im.get_width()!=im.get_height():
  quit(1)
  return
 var main=im.duplicate() as Image
 main.resize(192,192,Image.INTERPOLATE_LANCZOS)
 if main.save_png("res://assets/art/launcher.png")!=OK:
  quit(1)
  return
 var bg=Image.create(432,432,false,Image.FORMAT_RGBA8)
 bg.fill(Color("#fbc967"))
 var fg=Image.create(432,432,false,Image.FORMAT_RGBA8)
 fg.fill(Color(0,0,0,0))
 im.convert(Image.FORMAT_RGBA8)
 im.resize(300,300,Image.INTERPOLATE_LANCZOS)
 for y in range(300):
  for x in range(300):
   var c=im.get_pixel(x,y)
   if (x<45 or x>254) and (y<45 or y>254) and maxf(c.r,maxf(c.g,c.b))<.16:
    im.set_pixel(x,y,Color(0,0,0,0))
 fg.blit_rect(im,Rect2i(0,0,300,300),Vector2i(66,66))
 var a=fg.save_png("res://assets/art/launcher_foreground.png")
 var b=bg.save_png("res://assets/art/launcher_background.png")
 print("APPROVED_ICON_OK")
 quit(0 if a==OK and b==OK else 1)
