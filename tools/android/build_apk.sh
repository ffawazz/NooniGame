#!/usr/bin/env bash
# Builds build/NooniGame.apk from godot/ on Linux/macOS/WSL, without Android Studio.
#
# What it needs: Godot 4.4.1 (path in $GODOT or on PATH as `godot`), a JDK (java + keytool), python3, curl, unzip.
# What it sets up (under ~/.cache/nooni-android, safe to delete):
#   * Godot's Android export template (taken from the official ~1.2 GB export-templates download, once)
#   * Google's apksig library (Maven Central) wrapped as a tiny stand-in for the SDK's `apksigner`
#   * a debug keystore and the little fake "SDK" folder Godot's exporter checks for
# The APK is signed with a throwaway debug key (v2 scheme, Android 7+). That is fine for sideloading, not for Play.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CACHE="${NOONI_ANDROID_CACHE:-$HOME/.cache/nooni-android}"
GODOT="${GODOT:-$(command -v godot || true)}"
VERSION="4.4.1.stable"
TEMPLATES="$HOME/.local/share/godot/export_templates/$VERSION"
SDK="$CACHE/sdk"
mkdir -p "$CACHE" "$ROOT/build"

[ -x "$GODOT" ] || { echo "Set GODOT=/path/to/godot (4.4.1)"; exit 1; }
command -v java >/dev/null && command -v keytool >/dev/null || { echo "Install a JDK (java + keytool)"; exit 1; }

# 1. Export templates (only the Android one is needed).
if [ ! -f "$TEMPLATES/android_release.apk" ]; then
  echo "Downloading Godot export templates (about 1.2 GB, once)..."
  curl -fL -o "$CACHE/templates.tpz" "https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz"
  mkdir -p "$TEMPLATES"
  unzip -oj "$CACHE/templates.tpz" "templates/android_release.apk" "templates/version.txt" -d "$TEMPLATES/"
fi

# 2. apksig, the signer library.
if [ ! -f "$CACHE/apksig.jar" ]; then
  curl -fL -o "$CACHE/apksig.jar" "https://repo1.maven.org/maven2/com/android/tools/build/apksig/2.3.0/apksig-2.3.0.jar"
fi
cp "$ROOT/tools/android/Sign.java" "$ROOT/tools/android/align_zip.py" "$CACHE/"

# 3. A debug keystore.
if [ ! -f "$CACHE/debug.keystore" ]; then
  keytool -genkeypair -keystore "$CACHE/debug.keystore" -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Nooni Debug,O=Nooni,C=SA"
fi

# 4. The stand-in SDK: the pieces Godot looks for, with our own `apksigner` (aligns, then signs with apksig).
mkdir -p "$SDK/platform-tools" "$SDK/build-tools/34.0.0" "$SDK/cmdline-tools/latest/bin" "$SDK/platforms/android-34"
cat > "$SDK/build-tools/34.0.0/apksigner" <<SIGNER
#!/bin/bash
TOOLS="$CACHE"
JAVA="java --add-exports java.base/sun.security.x509=ALL-UNNAMED --add-exports java.base/sun.security.pkcs=ALL-UNNAMED --add-exports java.base/sun.security.util=ALL-UNNAMED -cp \$TOOLS/apksig.jar"
if [ "\$1" = "--version" ]; then echo "0.9"; exit 0; fi
if [ "\$1" = "verify" ]; then exec \$JAVA \$TOOLS/Sign.java verify "\${@: -1}"; fi
KS=""; PASS=""; KEYPASS=""; ALIAS="androiddebugkey"; OUT=""; ARGS=("\$@")
for ((i=0;i<\${#ARGS[@]};i++)); do
  case "\${ARGS[i]}" in
    --ks) KS="\${ARGS[i+1]}";; --ks-pass) PASS="\${ARGS[i+1]#pass:}";; --key-pass) KEYPASS="\${ARGS[i+1]#pass:}";;
    --ks-key-alias) ALIAS="\${ARGS[i+1]}";; --out) OUT="\${ARGS[i+1]}";;
  esac
done
IN="\${@: -1}"; [ -z "\$OUT" ] && OUT="\$IN"; [ -z "\$KEYPASS" ] && KEYPASS="\$PASS"
TMP=\$(mktemp --suffix=.apk 2>/dev/null || mktemp -t nooni).apk
python3 -I "\$TOOLS/align_zip.py" "\$IN" "\$TMP" || exit 1
\$JAVA "\$TOOLS/Sign.java" sign "\$KS" "\$PASS" "\$ALIAS" "\$KEYPASS" "\$TMP" "\$OUT.signed" || exit 1
mv "\$OUT.signed" "\$OUT"; rm -f "\$TMP" "\$OUT.idsig"
SIGNER
printf '#!/bin/bash\necho "Android Debug Bridge version 1.0.41"\n' > "$SDK/platform-tools/adb"
printf '#!/bin/bash\necho stub\n' > "$SDK/cmdline-tools/latest/bin/sdkmanager"
printf '#!/bin/bash\nexit 0\n' > "$SDK/build-tools/34.0.0/zipalign"
touch "$SDK/platforms/android-34/android.jar"
chmod +x "$SDK"/build-tools/34.0.0/* "$SDK/platform-tools/adb" "$SDK/cmdline-tools/latest/bin/sdkmanager"

# 5. Tell Godot where everything is, then export.
JAVA_HOME_DIR="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-4.4.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA_HOME_DIR"
export/android/debug_keystore = "$CACHE/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
SETTINGS

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$CACHE/debug.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="android"
"$GODOT" --headless --path "$ROOT/godot" --import
rm -f "$ROOT/build/NooniGame.apk"
"$GODOT" --headless --path "$ROOT/godot" --export-release "Android"
java --add-exports java.base/sun.security.x509=ALL-UNNAMED --add-exports java.base/sun.security.pkcs=ALL-UNNAMED \
  --add-exports java.base/sun.security.util=ALL-UNNAMED -cp "$CACHE/apksig.jar" "$CACHE/Sign.java" verify "$ROOT/build/NooniGame.apk"
ls -la "$ROOT/build/NooniGame.apk"
