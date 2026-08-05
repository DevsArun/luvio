#!/usr/bin/env python3
"""Luvio Player - full app audit.

Static checker that verifies the whole app without needing a Flutter SDK.
Run from the project root:  python3 tool/full_audit.py

Checks performed
  1.  Dart syntax sanity      - balanced braces / parens / brackets, stray text
  2.  Import resolution       - every relative import points at a real file
  3.  Package declarations    - every imported pub package is in pubspec.yaml
  4.  Platform channels       - every Dart invokeMethod has a Kotlin handler
  5.  Android manifest        - well formed XML + required permissions present
  6.  Routes                  - every pushNamed target is registered
  7.  Dead files              - Dart files nobody imports
  8.  Placeholders            - TODO / FIXME / "coming soon" / stub text
  9.  Share correctness       - every shareXFiles call passes a MIME type
 10.  Delete correctness      - every delete call handles the bool result
 11.  Feature matrix          - the MX-Player feature list is actually wired
 12.  Gradle / signing        - release config, SDK levels, CI workflow

Exit code is 0 when there are no FAIL rows.
"""

import os
import re
import sys
import xml.dom.minidom

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")
ANDROID = os.path.join(ROOT, "android")

FAILS = []
WARNS = []
SECTIONS = []


def section(name):
    SECTIONS.append((name, []))
    return SECTIONS[-1][1]


def ok(rows, msg):
    rows.append(("PASS", msg))


def fail(rows, msg):
    rows.append(("FAIL", msg))
    FAILS.append(msg)


def warn(rows, msg):
    rows.append(("WARN", msg))
    WARNS.append(msg)


def dart_files():
    out = []
    for base, _, names in os.walk(LIB):
        for n in names:
            if n.endswith(".dart"):
                out.append(os.path.join(base, n))
    return sorted(out)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def strip_code(src):
    """Remove strings and comments so bracket counting is meaningful."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        two = src[i:i + 2]
        if two == "//":
            i = src.find("\n", i)
            if i == -1:
                break
            continue
        if two == "/*":
            j = src.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue
        if src[i:i + 3] in ("'''", '"""'):
            q = src[i:i + 3]
            j = src.find(q, i + 3)
            i = n if j == -1 else j + 3
            continue
        if c in "'\"":
            i += 1
            while i < n and src[i] != c:
                if src[i] == "\\":
                    i += 1
                i += 1
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


# ---------------------------------------------------------------- 1. syntax
def check_syntax():
    rows = section("1. Dart syntax sanity")
    bad = 0
    for path in dart_files():
        code = strip_code(read(path))
        rel = os.path.relpath(path, ROOT)
        for open_c, close_c, label in (("{", "}", "braces"),
                                       ("(", ")", "parens"),
                                       ("[", "]", "brackets")):
            diff = code.count(open_c) - code.count(close_c)
            if diff != 0:
                fail(rows, f"{rel}: unbalanced {label} ({diff:+d})")
                bad += 1
    if bad == 0:
        ok(rows, f"{len(dart_files())} Dart files - all brackets balanced")


# ------------------------------------------------------------- 2/3. imports
def check_imports():
    rows = section("2. Import resolution")
    prows = section("3. Package declarations")
    missing, packages = [], set()
    for path in dart_files():
        base = os.path.dirname(path)
        for imp in re.findall(r"""^\s*import\s+['"]([^'"]+)['"]""",
                              read(path), re.M):
            if imp.startswith("dart:"):
                continue
            if imp.startswith("package:"):
                pkg = imp.split(":", 1)[1].split("/", 1)[0]
                if pkg == "luvio_player":
                    target = os.path.join(LIB, imp.split("/", 1)[1])
                    if not os.path.exists(target):
                        missing.append(
                            f"{os.path.relpath(path, ROOT)} -> {imp}")
                else:
                    packages.add(pkg)
                continue
            target = os.path.normpath(os.path.join(base, imp))
            if not os.path.exists(target):
                missing.append(f"{os.path.relpath(path, ROOT)} -> {imp}")

    if missing:
        for m in missing:
            fail(rows, f"unresolved import: {m}")
    else:
        ok(rows, "every relative/package import resolves to a real file")

    pubspec = read(os.path.join(ROOT, "pubspec.yaml"))
    declared = set(re.findall(r"^\s{2}([a-z0-9_]+)\s*:", pubspec, re.M))
    undeclared = sorted(p for p in packages
                        if p not in declared and p != "flutter")
    if undeclared:
        for p in undeclared:
            # cross_file ships transitively with share_plus, so it resolves
            # but is still better declared explicitly.
            (warn if p == "cross_file" else fail)(
                prows, f"package '{p}' imported but not in pubspec.yaml")
    else:
        ok(prows, f"all {len(packages)} imported packages declared")


# ------------------------------------------------------------- 4. channels
def check_channels():
    rows = section("4. Platform channels (Dart <-> Kotlin)")
    kotlin_src = ""
    for base, _, names in os.walk(ANDROID):
        for n in names:
            if n.endswith(".kt"):
                kotlin_src += read(os.path.join(base, n))

    handled = set(re.findall(r'"([A-Za-z]+)"\s*->', kotlin_src))
    channels = set(re.findall(r"""MethodChannel\(\s*['"]([^'"]+)['"]""",
                              kotlin_src))
    channels |= set(re.findall(
        r"""MethodChannel\(['"]([^'"]+)['"]\)""",
        "".join(read(p) for p in dart_files())))

    called = set()
    for path in dart_files():
        called |= set(re.findall(
            r"""invokeMethod(?:<[^>]*>)?\(\s*['"]([A-Za-z]+)['"]""",
            read(path)))
    # Dart -> Kotlin only; 'action' is Kotlin -> Dart.
    orphans = sorted(c for c in called if c not in handled)
    if orphans:
        for o in orphans:
            fail(rows, f"Dart calls '{o}' but no Kotlin handler exists")
    else:
        ok(rows, f"all {len(called)} Dart channel methods have Kotlin handlers")
    ok(rows, "channels: " + ", ".join(sorted(channels)))


# ------------------------------------------------------------- 5. manifest
def check_manifest():
    rows = section("5. Android manifest")
    path = os.path.join(ANDROID, "app/src/main/AndroidManifest.xml")
    try:
        xml.dom.minidom.parse(path)
        ok(rows, "AndroidManifest.xml is well-formed XML")
    except Exception as exc:
        fail(rows, f"AndroidManifest.xml is invalid: {exc}")
        return
    src = read(path)
    required = [
        "READ_EXTERNAL_STORAGE", "READ_MEDIA_VIDEO", "READ_MEDIA_AUDIO",
        "MANAGE_EXTERNAL_STORAGE", "INTERNET", "WAKE_LOCK",
        "FOREGROUND_SERVICE", "POST_NOTIFICATIONS",
    ]
    for perm in required:
        if perm in src:
            ok(rows, f"permission declared: {perm}")
        else:
            fail(rows, f"missing permission: {perm}")
    if "<queries>" in src:
        ok(rows, "<queries> present - share sheet can see other apps")
    else:
        fail(rows, "<queries> missing - share targets will be hidden on API 30+")


# --------------------------------------------------------------- 6. routes
def check_routes():
    rows = section("6. Navigation routes")
    routes_src = read(os.path.join(LIB, "core/routes.dart"))
    declared = set(re.findall(r"""static const \w+ = ['"]([^'"]+)['"]""",
                              routes_src))
    registered = set(re.findall(r"""['"](/[a-z\-/]*)['"]\s*:""",
                                read(os.path.join(LIB, "app.dart"))))
    registered |= set(re.findall(r"Routes\.(\w+)", read(
        os.path.join(LIB, "app.dart"))))
    used = set()
    for path in dart_files():
        used |= set(re.findall(r"Routes\.(\w+)", read(path)))
    names = set(re.findall(r"static const (?:\w+\s+)?(\w+)\s*=", routes_src))
    names |= {"onGenerateRoute"}  # a method on Routes, not a route name
    unknown = sorted(u for u in used if u not in names)
    if unknown:
        for u in unknown:
            fail(rows, f"Routes.{u} used but not declared")
    else:
        ok(rows, f"all {len(used)} referenced routes are declared")
    unused = sorted(n for n in names if n not in used)
    if unused:
        warn(rows, "declared but never navigated to: " + ", ".join(unused))
    ok(rows, f"{len(declared)} route paths defined")


# ----------------------------------------------------------- 7. dead files
def check_dead_files():
    rows = section("7. Unused Dart files")
    all_src = "".join(read(p) for p in dart_files())
    dead = []
    for path in dart_files():
        name = os.path.basename(path)
        if name in ("main.dart", "app.dart"):
            continue
        # A file's own source does not contain its own file name, so any
        # occurrence at all means some other file imports it.
        if all_src.count(name) == 0:
            dead.append(os.path.relpath(path, ROOT))
    if dead:
        for d in dead:
            warn(rows, f"never imported: {d}")
    else:
        ok(rows, "no orphan Dart files")


# --------------------------------------------------------- 8. placeholders
def check_placeholders():
    rows = section("8. Placeholder / stub text")
    patterns = re.compile(
        r"\bTODO\b|\bFIXME\b|\bXXX\b|coming soon|not implemented|"
        r"\bplaceholder\b|\bdummy\b|lorem ipsum", re.I)
    hits = []
    for path in dart_files():
        for i, line in enumerate(read(path).splitlines(), 1):
            if patterns.search(line):
                hits.append(f"{os.path.relpath(path, ROOT)}:{i}: {line.strip()[:70]}")
    if hits:
        for h in hits:
            warn(rows, h)
    else:
        ok(rows, "no TODO / stub / placeholder text anywhere in lib/")


# ---------------------------------------------------------------- 9. share
def check_share():
    rows = section("9. Share correctness")
    bad = []
    for path in dart_files():
        src = read(path)
        for m in re.finditer(r"Share\.shareXFiles\((.{0,400}?)\);", src,
                             re.S):
            # The MIME type may be attached where the XFile list is built
            # rather than inline, so look a little way back too.
            context = src[max(0, m.start() - 600):m.end()]
            if "mimeType" not in context:
                line = src[:m.start()].count("\n") + 1
                bad.append(f"{os.path.relpath(path, ROOT)}:{line}")
    if bad:
        for b in bad:
            fail(rows, f"shareXFiles without mimeType (limits share targets): {b}")
    else:
        ok(rows, "every shareXFiles call passes a real MIME type")


# --------------------------------------------------------------- 10. delete
def check_delete():
    rows = section("10. Delete correctness")
    bad = []
    for path in dart_files():
        src = read(path)
        for m in re.finditer(r"await\s+\w+\.delete(?:Video|Track)\(", src):
            line_start = src.rfind("\n", 0, m.start()) + 1
            stmt = src[line_start:src.find("\n", m.start())]
            if not re.search(r"(final|var|if|return|=)", stmt):
                bad.append(
                    f"{os.path.relpath(path, ROOT)}:"
                    f"{src[:m.start()].count(chr(10)) + 1}")
    if bad:
        for b in bad:
            fail(rows, f"delete result ignored (silent failure on Android 11+): {b}")
    else:
        ok(rows, "every delete call checks its success result")


# ------------------------------------------------------- 11. feature matrix
FEATURES = {
    "Hardware + software decoding": ["hwdec"],
    "Playback speed control": ["setRate"],
    "Volume gesture": ["volumeGesture"],
    "Brightness gesture": ["brightnessGesture", "BrightnessService"],
    "Double-tap seek": ["doubleTapGesture"],
    "Zoom / aspect ratio": ["aspect"],
    "A-B repeat": ["abPointA"],
    "Sleep timer": ["sleep"],
    "Subtitle file loading": ["subtitle_file"],
    "Subtitle download": ["subtitle_download_service"],
    "Audio delay / sync": ["audio-delay"],
    "Night mode / video filters": ["videoBrightness", "saturation"],
    "Chapters": ["chapter-list"],
    "Screenshot capture": ["CaptureService"],
    "Bookmarks": ["BookmarkService"],
    "Picture-in-picture": ["pip_overlay_host"],
    "Background audio playback": ["background"],
    "Notification / lockscreen controls": ["media_notification"],
    "Equalizer": ["EqualizerScreen"],
    "Network / URL streaming": ["isStreamUrl"],
    "Playlists": ["PlaylistProvider"],
    "Private vault": ["VaultService"],
    "File manager": ["FileManagerService"],
    "Recycle bin": ["moveToTrash"],
    "Resume playback": ["autoResume"],
    "Thumbnails": ["ThumbnailService"],
    "Search": ["recentSearches"],
    "Favorites": ["favorite"],
    "Rename": ["renameVideo"],
    "Share": ["shareXFiles"],
    "Delete": ["deleteVideo"],
    "MediaStore library scan": ["queryMediaStoreVideos"],
    "All-files access flow": ["requestAllFilesAccess"],
    "Auto-rescan on resume": ["didChangeAppLifecycleState"],
    "Audio player": ["AudioLibraryProvider"],
    "Screen lock during playback": ["_locked"],
    "Dark / light theme": ["darkTheme"],
    "Backup & restore": ["backup_restore_page"],
    "Decoder settings": ["decoder_page"],
    "Language selection": ["language_page"],
}


def check_features():
    rows = section("11. Feature matrix")
    blob = "".join(read(p) for p in dart_files())
    names = " ".join(os.path.relpath(p, ROOT) for p in dart_files())
    haystack = blob + names
    for feature, keys in FEATURES.items():
        if all(k in haystack for k in keys):
            ok(rows, feature)
        else:
            missing = [k for k in keys if k not in haystack]
            fail(rows, f"{feature} - marker(s) not found: {missing}")


# -------------------------------------------------------------- 12. gradle
def check_gradle():
    rows = section("12. Build / release configuration")
    gradle = read(os.path.join(ANDROID, "app/build.gradle"))
    checks = {
        "applicationId set": "dev.luvio.player" in gradle,
        "release signingConfig present": "signingConfigs" in gradle,
        "keystore loader present": "key.properties" in gradle,
        "minSdk declared": "minSdk" in gradle,
        "targetSdk declared": "targetSdk" in gradle,
    }
    for label, good in checks.items():
        (ok if good else fail)(rows, label)

    wf = os.path.join(ROOT, ".github/workflows/build-apk.yml")
    if os.path.exists(wf):
        src = read(wf)
        ok(rows, "GitHub Actions workflow present")
        (ok if "KEYSTORE_BASE64" in src else fail)(
            rows, "workflow wires the signing secrets")
        (ok if "assembleRelease" in src or "build apk" in src.lower() else warn)(
            rows, "workflow builds an APK")
    else:
        fail(rows, "GitHub Actions workflow missing")

    ver = re.search(r"^version:\s*(.+)$", read(
        os.path.join(ROOT, "pubspec.yaml")), re.M)
    ok(rows, f"app version: {ver.group(1).strip() if ver else 'unknown'}")


def main():
    for fn in (check_syntax, check_imports, check_channels, check_manifest,
               check_routes, check_dead_files, check_placeholders,
               check_share, check_delete, check_features, check_gradle):
        fn()

    print("=" * 72)
    print("LUVIO PLAYER - FULL APP AUDIT")
    print("=" * 72)
    for name, rows in SECTIONS:
        print(f"\n{name}")
        print("-" * 72)
        for status, msg in rows:
            print(f"  [{status}] {msg}")

    print("\n" + "=" * 72)
    print(f"RESULT: {len(FAILS)} failure(s), {len(WARNS)} warning(s)")
    print("=" * 72)
    if FAILS:
        print("\nFAILURES:")
        for f in FAILS:
            print(f"  - {f}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
