import hashlib, json, pathlib, re, shutil, subprocess, tempfile, urllib.request, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/imported"
SOURCES = {
    "kenney": "https://kenney.nl/media/pages/assets/food-kit/83086fa91c-1719418518/kenney_food-kit.zip",
    "kaykit": "https://github.com/KayKit-Game-Assets/KayKit-Restaurant-Bits-1.0/archive/153c8a7535b48237854cb54ff6890679f8c574d1.zip",
}
WANTED = {
    "kenney": {"pizza": ["pizza"], "tomato": ["tomato"], "mushroom": ["mushroom"], "cheese": ["cheese"], "pepper": ["pepper"], "onion": ["onion"], "plate": ["plate"]},
    "kaykit": {"oven": ["oven", "stove"], "fridge": ["fridge", "refrigerator"], "counter": ["counter", "cabinet"], "board": ["cuttingboard", "choppingboard", "cutting_board", "chopping_board"], "bowl": ["bowl"], "sink": ["sink"]},
}
def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())
def safe_extract(z, root):
    for info in z.infolist():
        p = (root / info.filename).resolve()
        if not p.is_relative_to(root.resolve()):
            raise ValueError("Unsafe archive path")
    z.extractall(root)
def copy_model(src, dest, root):
    dest.mkdir(parents=True, exist_ok=True)
    target = dest / src.name
    shutil.copy2(src, target)
    if src.suffix.lower() == ".gltf":
        doc = json.loads(src.read_text(encoding="utf-8"))
        for part in doc.get("buffers", []) + doc.get("images", []):
            uri = part.get("uri", "")
            if not uri or uri.startswith("data:"):
                continue
            from urllib.parse import unquote
            uri = unquote(uri)
            dependency = (src.parent / uri).resolve()
            if not dependency.is_relative_to(root.resolve()) or not dependency.is_file():
                raise ValueError(f"Missing/unsafe model dependency: {dependency}")
            relative = pathlib.Path(uri)
            if relative.is_absolute() or ".." in relative.parts:
                # Rewrite references into a private dependency folder.
                new = "deps/" + hashlib.sha256(uri.encode()).hexdigest()[:12] + dependency.suffix
                part["uri"] = new
                relative = pathlib.Path(new)
            dst = dest / relative
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dependency, dst)
        target.write_text(json.dumps(doc), encoding="utf-8")
    return target
def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    manifest = {}
    with tempfile.TemporaryDirectory() as tmp:
        for pack, url in SOURCES.items():
            root = pathlib.Path(tmp) / pack
            root.mkdir()
            archive = pathlib.Path(tmp) / (pack + ".zip")
            subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--max-time", "120", "-o", str(archive), url], check=True)
            with zipfile.ZipFile(archive) as z:
                safe_extract(z, root)
            models = [p for p in root.rglob("*") if p.suffix.lower() in (".glb", ".gltf")]
            for key, terms in WANTED[pack].items():
                options = [p for p in models if any(norm(t) in norm(p.stem) for t in terms) and not any(x in p.stem.lower() for x in ("bacon","pork","ham","beer","wine","sausage","salami","pepperoni"))]
                if not options:
                    print("Optional model not found:", key)
                    continue
                options.sort(key=lambda p: (min((0 if norm(p.stem)==norm(t) else 1) for t in terms), p.suffix.lower()!=".glb", len(p.stem), str(p)))
                model = options[0]
                target = copy_model(model, OUT / key, root)
                manifest[key] = {"path": "res://" + target.relative_to(ROOT).as_posix(), "source": pack, "original": str(model.relative_to(root)), "sha256": hashlib.sha256(target.read_bytes()).hexdigest()}
            for lic in root.rglob("*"):
                if lic.is_file() and lic.name.lower() in ("license.txt","license.md","license"):
                    shutil.copy2(lic, OUT / (pack + "_LICENSE.txt"))
                    break
    for required in ("pizza","tomato","oven","counter"):
        if required not in manifest:
            raise SystemExit("Required source asset not found: " + required)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("Imported model keys:", sorted(manifest))
if __name__ == "__main__":
    main()
