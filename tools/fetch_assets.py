import hashlib, json, pathlib, re, shutil, struct, subprocess, tempfile, zipfile
from urllib.parse import unquote

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/imported"
SOURCES = {
    "kenney": "https://kenney.nl/media/pages/assets/food-kit/83086fa91c-1719418518/kenney_food-kit.zip",
    "kaykit": "https://github.com/KayKit-Game-Assets/KayKit-Restaurant-Bits-1.0/archive/153c8a7535b48237854cb54ff6890679f8c574d1.zip",
}
WANTED = {
    "kenney": {"pizza": ["pizza"], "tomato": ["tomato"], "mushroom": ["mushroom"], "cheese": ["cheese"], "pepper": ["pepper"], "onion": ["onion"], "plate": ["plate"], "rolling_pin": ["rolling_pin", "rollingpin"], "olive": ["olive"], "basil": ["basil"], "pizza_slice": ["pizza_slice", "pizzaslice"], "corn": ["corn"]},
    "kaykit": {"oven": ["oven", "stove"], "fridge": ["fridge", "refrigerator"], "counter": ["counter", "cabinet", "worktop", "kitchen_table"], "board": ["cuttingboard", "choppingboard", "cutting_board", "chopping_board"], "bowl": ["bowl"], "sink": ["kitchencounter_sink", "sink"], "cabinet": ["kitchencabinet"], "worktop": ["kitchentable_A_large"], "hood": ["extractorhood"], "jar": ["jar_A_medium"], "jar_b": ["jar_B_small"], "crate_tomato": ["crate_tomatoes"], "crate_cheese": ["crate_cheese"], "knife": ["knife"], "dishrack": ["dishrack_plates"], "shelf": ["shelf_papertowel_decorated"], "tomato_slice": ["food_ingredient_tomato_slice"], "cheese_slice": ["food_ingredient_cheese_slice"], "onion_rings": ["food_ingredient_onion_rings"], "pot": ["pot_A"], "menu": ["menu"], "carrot": ["food_ingredient_carrot"], "carrot_slice": ["food_ingredient_carrot_pieces", "food_ingredient_carrot_chopped"]},
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
    """Preserve external images/buffers for both GLB and textual glTF.
    GLB is not necessarily self-contained; retain all original binary chunks.
    """
    dest.mkdir(parents=True, exist_ok=True)
    target = dest / src.name
    is_glb = src.suffix.lower() == ".glb"
    chunks = []
    if is_glb:
        raw = src.read_bytes()
        magic, version, size = struct.unpack_from("<4sII", raw)
        if magic != b"glTF" or version != 2 or size != len(raw):
            raise ValueError("Invalid GLB: " + str(src))
        offset = 12
        while offset < size:
            count, kind = struct.unpack_from("<I4s", raw, offset)
            offset += 8
            if offset + count > size:
                raise ValueError("Truncated GLB: " + str(src))
            chunks.append((kind, raw[offset:offset+count]))
            offset += count
        if not chunks or chunks[0][0] != b"JSON":
            raise ValueError("Missing GLB JSON chunk")
        doc = json.loads(chunks[0][1].decode("utf-8").rstrip(" \x00"))
    else:
        doc = json.loads(src.read_text(encoding="utf-8-sig"))

    for part in doc.get("buffers", []) + doc.get("images", []):
        uri = part.get("uri", "")
        if not uri or uri.startswith("data:"):
            continue
        uri = unquote(uri).replace("\\", "/")
        dependency = (src.parent / uri).resolve()
        if not dependency.is_relative_to(root.resolve()):
            raise ValueError("Unsafe external resource: " + uri)
        if not dependency.is_file():
            # Some packs use case-insensitive paths; only accept an unambiguous file.
            matches = [q for q in root.rglob("*") if q.is_file() and q.name.casefold() == pathlib.Path(uri).name.casefold()]
            if len(matches) != 1:
                raise ValueError(f"Missing or ambiguous external resource {uri} for {src}")
            dependency = matches[0].resolve()
        if not dependency.is_relative_to(root.resolve()):
            raise ValueError("Unsafe dependency: " + str(dependency))
        new_uri = "deps/" + hashlib.sha256(uri.encode()).hexdigest()[:12] + dependency.suffix.lower()
        dst = dest / new_uri
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(dependency, dst)
        part["uri"] = new_uri
        print("Copied model dependency:", src.name, uri, flush=True)

    if is_glb:
        encoded = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        encoded += b" " * ((-len(encoded)) % 4)
        chunks[0] = (b"JSON", encoded)
        body = b"".join(struct.pack("<I4s", len(data), kind) + data for kind, data in chunks)
        target.write_bytes(struct.pack("<4sII", b"glTF", 2, 12 + len(body)) + body)
    else:
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
            print("Fetching", pack, url, flush=True)
            candidates = [(url, None)]
            if pack == "kenney":
                candidates.append(("https://github.com/WaviestSun/atelier-packs/releases/download/packs-2/kenney_food-kit.zip", "cdad90853682499b94c9fda2f87678b24bfd8f3264e0ed323f6b6a27fd7c6f6f"))
            if pack == "kaykit":
                candidates.append(("https://codeload.github.com/KayKit-Game-Assets/KayKit-Restaurant-Bits-1.0/zip/153c8a7535b48237854cb54ff6890679f8c574d1", None))
            for candidate, checksum in candidates:
                try:
                    subprocess.run(["curl", "--fail", "--location", "--retry", "2", "--max-time", "90", "--user-agent", "PizzavitoAssetBuilder/1.0", "-o", str(archive), candidate], check=True)
                    if not zipfile.is_zipfile(archive):
                        raise ValueError("Downloaded file is not a ZIP")
                    if checksum and hashlib.sha256(archive.read_bytes()).hexdigest() != checksum:
                        raise ValueError("Fallback archive checksum mismatch")
                    break
                except (subprocess.CalledProcessError, ValueError) as err:
                    print("Asset download failed:", candidate, err, flush=True)
            else:
                raise SystemExit("All download sources failed: " + pack)
            with zipfile.ZipFile(archive) as z:
                safe_extract(z, root)
            models = [p for p in root.rglob("*") if p.suffix.lower() in (".glb", ".gltf")]
            print(pack, "model count:", len(models), flush=True)
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
