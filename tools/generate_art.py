"""Generate original illustrated recipe cards and procedural food texture maps."""
import ast, pathlib, math, random, struct, zlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/"assets/art"
OUT.mkdir(parents=True,exist_ok=True)
BOOK=ast.literal_eval((ROOT/"game.gd").read_text().split("const BOOK = ",1)[1].split("\nvar lang",1)[0].strip())
PALETTE={"sauce":"#c24529","tomato":"#dc5035","mushroom":"#c7a17d","cheese":"#f5db8c","pepper":"#6ca849","onion":"#b083b6","olive":"#40523a","corn":"#e9c548","carrot":"#e68c35"}
def svg(body,w=256,h=256):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'
def ingredient(key,x,y,r):
    c=PALETTE[key]
    if key=="olive" or key=="onion":
        return f'<circle cx="{x}" cy="{y}" r="{r}" fill="none" stroke="{c}" stroke-width="{r*.53}"/>'
    if key=="mushroom":
        return f'<path d="M{x-r},{y} Q{x-r},{y-r*1.6} {x},{y-r} Q{x+r},{y-r*1.6} {x+r},{y} Z" fill="{c}" stroke="#8b694f" stroke-width="1"/><rect x="{x-r*.25}" y="{y-1}" width="{r*.5}" height="{r*.8}" rx="2" fill="#f4e4c8"/>'
    if key=="cheese":
        return f'<rect x="{x-r}" y="{y-r*.45}" width="{r*2}" height="{r*.9}" rx="3" fill="{c}" stroke="#dba74e" stroke-width="1"/>'
    if key=="pepper":
        return f'<path d="M{x-r},{y-r*.7} Q{x},{y+r*1.6} {x+r},{y-r*.7}" fill="none" stroke="{c}" stroke-width="{r*.65}" stroke-linecap="round"/>'
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}" stroke="#9d613c" stroke-width="1"/><ellipse cx="{x-r*.2}" cy="{y-r*.25}" rx="{r*.38}" ry="{r*.18}" fill="#fff2ce" opacity=".68"/>'
def profile(shape,a):
    if shape=="star":return 1+.20*math.cos(5*a)
    if shape=="heart":return 1-.19*math.sin(a)-.10*math.cos(2*a)+.05*math.cos(4*a)
    if shape=="square":return .78/max(abs(math.cos(a)),abs(math.sin(a)))
    if shape=="mini":return .77
    return 1
def outline(shape,r):
    return " ".join(f"{128+math.cos(a)*r*profile(shape,a):.2f},{128+math.sin(a)*r*profile(shape,a):.2f}" for a in [math.tau*i/120 for i in range(120)])
def pizza(shape,ingredients,seed):
    rng=random.Random(seed)
    body='<defs><radialGradient id="crust"><stop stop-color="#fff0bc"/><stop offset=".78" stop-color="#e6a75c"/><stop offset="1" stop-color="#b96b2d"/></radialGradient><radialGradient id="sauce"><stop stop-color="#f48d4c"/><stop offset="1" stop-color="#c5472a"/></radialGradient></defs>'
    body+='<ellipse cx="128" cy="144" rx="105" ry="99" fill="#4c3522" opacity=".2"/>'
    body+=f'<polygon points="{outline(shape,100)}" fill="url(#crust)" stroke="#9d5b29" stroke-width="3"/><polygon points="{outline(shape,83)}" fill="url(#sauce)"/>'
    if "cheese" in ingredients:
        for i in range(70):
            a=rng.random()*math.tau;r=math.sqrt(rng.random())*73*profile(shape,a)
            body+=ingredient("cheese",128+math.cos(a)*r,128+math.sin(a)*r,3.2)
    for i in range(30):
        a=i*2.39996;r=math.sqrt((i+1)/30)*66*profile(shape,a)
        body+=ingredient(ingredients[i%len(ingredients)],128+math.cos(a)*r,128+math.sin(a)*r,5.5 if ingredients[i%len(ingredients)]!="corn" else 3.6)
    for i in range(48):
        a=rng.random()*math.tau;r=profile(shape,a)*rng.uniform(87,96)
        body+=f'<circle cx="{128+math.cos(a)*r:.1f}" cy="{128+math.sin(a)*r:.1f}" r="{rng.uniform(.6,1.8):.1f}" fill="#8e4d23" opacity=".42"/>'
    return body
for i,row in enumerate(BOOK):
    (OUT/f"recipe_{i:02}.svg").write_text(svg(pizza(row[3],row[4],i+9)))
for key in PALETTE:
    body='<circle cx="128" cy="128" r="100" fill="#fff1d8" stroke="#d5b581" stroke-width="5"/>'
    for a in range(3):
        body+=ingredient(key,128+math.cos(a*2.09)*35,128+math.sin(a*2.09)*35,37)
    (OUT/(key+".svg")).write_text(svg(body))
# Original polished store icon, rasterised by Godot for Android launcher export.
icon='<defs><linearGradient id="bg" x2="0" y2="1"><stop stop-color="#f9ce70"/><stop offset="1" stop-color="#ed9540"/></linearGradient></defs><rect width="256" height="256" rx="53" fill="url(#bg)"/><path d="M0 210 Q100 154 256 204 V256 H0Z" fill="#ad4d2e" opacity=".22"/>'+pizza("round",["tomato","cheese","pepper","olive","mushroom"],99)+'<path d="M206 26l5 13 13 5-13 5-5 13-5-13-13-5 13-5z" fill="#fff5d4"/>'
(ROOT/"icon.svg").write_text(svg(icon,512,512))
def png(path,pixels,n):
    def chunk(t,d):return struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d)&0xffffffff)
    raw=b"".join(b"\0"+bytes(pixels[y*n*3:(y+1)*n*3]) for y in range(n))
    path.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",n,n,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(raw,9))+chunk(b"IEND",b""))
for index,key in enumerate(("dough","crust","sauce","cheese")):
    rng=random.Random(410+index);n=256; pixels=[]
    for y in range(n):
        for x in range(n):
            a=math.sin(x*.13+math.sin(y*.12)*2)*math.cos(y*.17)
            b=math.sin(x*.041+y*.07)*.5+math.cos(x*.11-y*.05)*.5
            v=int(226+13*a+9*b+rng.randrange(-13,14))
            if key=="crust" and rng.random()<.035:v-=45
            if key=="sauce" and rng.random()<.045:v-=25
            v=max(95,min(255,v))
            pixels.extend((v,v,v))
    png(OUT/(key+".png"),pixels,n)
print("Generated",len(BOOK),"original recipe illustrations and texture maps")
