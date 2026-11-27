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
        try:
            with fetch("https://kenney.nl/media/pages/assets/ui-pack/f651646eab-1718203990/kenney_ui-pack.zip","ui.zip",tmp) as z:
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
