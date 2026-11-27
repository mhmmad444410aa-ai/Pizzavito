"""Optional real CC0 assets, consumed by the game when present."""
import pathlib, subprocess, zipfile, tempfile, shutil, json
ROOT = pathlib.Path(__file__).resolve().parents[1] / "assets/imported"
def fetch(url, name, tmp):
    p = tmp / name
    subprocess.run(["curl","-fsSL","--retry","2","--max-time","90",url,"-o",str(p)],check=True)
    if not zipfile.is_zipfile(p):
        raise ValueError("Not a ZIP: "+name)
    return zipfile.ZipFile(p)
def copy_entry(z, entry, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    with z.open(entry) as src, dest.open("wb") as dst:
        shutil.copyfileobj(src,dst)
def main():
    report = {}
    with tempfile.TemporaryDirectory() as raw:
        tmp = pathlib.Path(raw)
        try:
            with fetch("https://ambientcg.com/get?file=Wood091B_2K-JPG.zip","wood.zip",tmp) as z:
                for role, needle in [("color","_color.jpg"),("normal","_normalgl.jpg"),("roughness","_roughness.jpg")]:
                    options = [n for n in z.namelist() if n.lower().endswith(needle)]
                    if options:
                        copy_entry(z,options[0],ROOT/"surfaces"/("wood_"+role+".jpg"))
                assert (ROOT/"surfaces/wood_color.jpg").is_file()
                report["ambientCG Wood091B"] = "imported"
        except Exception as e:
            report["ambientCG Wood091B"] = "unavailable: "+str(e)
        for material, ident, resolution in [("marble","Marble019","2K"),("tile","Tiles091","2K"),("stone","Wood019","2K"),("prep","Wood001","4K"),("sauceboard","Tiles062","4K"),("bakeboard","Tiles055","4K"),("cutboard","Marble001","4K"),("packboard","Wood091B","4K")]:
            try:
                with fetch("https://ambientcg.com/get?file="+ident+"_"+resolution+"-JPG.zip",material+".zip",tmp) as z:
                    entries=[n for n in z.namelist() if n.lower().endswith("_color.jpg")]
                    if not entries: raise ValueError("Missing colour map")
                    copy_entry(z,entries[0],ROOT/"surfaces"/(material+"_color.jpg"))
                    report[ident]="imported"
            except Exception as e:
                report[ident]="unavailable: "+str(e)
        try:
            sources = ["https://opengameart.org/sites/default/files/kenney_ui-pack.zip","https://kenney.nl/media/pages/assets/ui-pack/f651646eab-1718203990/kenney_ui-pack.zip"]
            for source in sources:
                try:
                    ui_archive = fetch(source,"ui.zip",tmp)
                    break
                except Exception as exc:
                    print("UI source failed:",source,exc,flush=True)
            else:
                raise ValueError("All UI download sources failed")
            with ui_archive as z:
                options = [n for n in z.namelist() if n.lower().endswith(".png") and "button" in pathlib.PurePosixPath(n).name.lower() and "green" in n.lower() and not any(x in n.lower() for x in ("pressed","disabled","outline","icon"))]
                if not options:
                    options = [n for n in z.namelist() if n.lower().endswith(".png") and "button" in pathlib.PurePosixPath(n).name.lower() and "rectangle" in n.lower() and "pressed" not in n.lower()]
                if not options:
                    raise ValueError("No matching button image")
                options.sort(key=lambda n:("rectangle" not in n.lower(),len(n),n))
                copy_entry(z,options[0],ROOT/"interface/button.png")
                report["Kenney UI Pack"] = options[0]
        except Exception as e:
            report["Kenney UI Pack"] = "unavailable: "+str(e)
    (ROOT/"visuals-report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(report,flush=True)
if __name__=="__main__":
    main()
