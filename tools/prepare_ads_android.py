from pathlib import Path
import os, zipfile, shutil
root=Path("android")
build=root/"build"
template=Path.home()/".local/share/godot/export_templates"/(os.environ["GODOT_VERSION"]+".stable")/"android_source.zip"
assert template.is_file(), template
build.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(template) as z: z.extractall(build)
(root/".build_version").write_text(os.environ["GODOT_VERSION"]+".stable\n")
(build/".gdignore").touch()
gradle=build/"build.gradle"
s=gradle.read_text()
assert "mavenCentral()" in s and "dependencies {" in s
s=s.replace("mavenCentral()", "mavenCentral()\n        maven { url 'https://developer.huawei.com/repo/' }",1)
s=s.replace("dependencies {", "dependencies {\n    implementation 'com.huawei.hms:ads-prime:3.4.91.300'",1)
gradle.write_text(s)
manifest=build/"AndroidManifest.xml"
s=manifest.read_text()
assert "</application>" in s
s=s.replace("</application>",'    <meta-data android:name="org.godotengine.plugin.v2.PizzavitoAds" android:value="com.godot.game.PizzavitoAds" />\n    </application>')
manifest.write_text(s)
dst=build/"src/com/godot/game/PizzavitoAds.java"
dst.parent.mkdir(parents=True,exist_ok=True)
shutil.copyfile("native_ads/PizzavitoAds.java",dst)
(build/"gradlew").chmod(0o755)
print("Petal Ads native template prepared")
