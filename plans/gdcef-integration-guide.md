# GDCEf Integration Guide — Web Content on Projection Surfaces

> **Status:** Build complete but crashes Godot 4.6 — ABI mismatch with godot-cpp 4.5. Artifacts saved at `cef_artifacts_built_4.5/`. Waiting for godot-cpp 4.6 branch.
> **Date:** 2026-04-03
> **Repo:** https://github.com/Lecrapouille/gdcef (branch: `godot-4.x`)
> **Local clone:** `external/gdcef/`

---

## What is GDCEf?

A GDExtension that embeds Chromium (via CEF) inside Godot 4.2+. It renders
web pages off-screen to a `Texture2D` that you can apply to any node —
including our `warp_polygon` on projection surfaces. This lets a surface
display any URL (localhost React app, dashboard, any web page).

---

## Prerequisites Already Installed

| Tool | Version | How |
|------|---------|-----|
| Python 3 | 3.12.12 | `mise` |
| CMake | 4.3.1 | `brew install cmake` |
| Ninja | 1.13.2 | `brew install ninja` |
| SCons | 4.10.1 | `pip install scons` |
| Xcode CLT | installed | `/Library/Developer/CommandLineTools` |
| progressbar (pip) | installed | `pip install -r requirements.txt` |

## What's Missing

**Full Xcode.app** — the CEF build compiles `cefsimple.app` which uses
Interface Builder (`.xib` → `.nib`). The `ibtool` command only ships with
the full Xcode, not Command Line Tools.

---

## Steps to Resume

### 1. Install Xcode

Download from the App Store (~12GB). Once installed:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify:
```bash
xcode-select -p
# Should show: /Applications/Xcode.app/Contents/Developer

xcrun --find ibtool
# Should show a path like: /Applications/Xcode.app/.../ibtool
```

### 2. Clean Previous Build Attempt

```bash
cd external/gdcef
rm -rf thirdparty/godot-4.5
rm -rf thirdparty/cef_binary/build
```

### 3. Run the Build

```bash
cd external/gdcef
python3 build.py 2>&1 | tee build.log
```

This takes ~15 minutes and does:
1. Clones + compiles `godot-cpp` 4.5 (~5 min)
2. Downloads CEF (~600MB) from Spotify CDN
3. Compiles CEF + `cefsimple.app` (~5 min) — **this is where it failed**
4. Compiles `libgdcef` (the GDExtension)
5. Compiles `gdCefRenderProcess` (subprocess)
6. Copies all artifacts to `cef_artifacts/` (~1GB)

### 4. Copy Artifacts into the Godot Project

After a successful build:

```bash
cp -r external/gdcef/cef_artifacts /path/to/your/godot/project/
```

The `cef_artifacts/` folder contains:
- `libgdcef.dylib` — the GDExtension library
- `cefsimple.app` — CEF subprocess host
- `*.pak`, `*.dat` — Chromium resources
- `locales/` — language packs
- `.gdextension` file — already included, no need to create one

### 5. Verify in Godot

Open the project in Godot 4.6. The GDExtension was built against godot-cpp
4.5 (latest available branch — no 4.6 branch exists yet in godot-cpp).
GDExtensions are designed to be forward-compatible within 4.x, so this
should work. If Godot shows an "incompatible extension" error, you'd need
to wait for a godot-cpp 4.6 branch.

---

## Godot-cpp Version Note

As of 2026-04-02, `godot-cpp` has branches: 4.0, 4.1, 4.2, 4.3, 4.4, 4.5.
No 4.6 branch exists yet. The build script (`external/gdcef/build.py` line 68)
is set to `GODOT_VERSION = "4.5"`. If a 4.6 branch appears later, change that
line and rebuild.

---

## Integration with Projection Surfaces

Once GDCEf is built and loaded, here's how to wire it into the projection
mapping app:

### Minimal GDScript Usage

```gdscript
# In a scene, add a GDCEF node and a TextureRect
extends Node2D

@onready var cef = $GDCEF
@onready var texture_rect = $TextureRect

func _ready():
    cef.initialize({})
    var browser = cef.create_browser("http://localhost:3000", texture_rect, {})
```

### Integration Plan for projection_surface.gd

1. Add a new content type `"web"` alongside existing solid color / test pattern
2. When content type is `"web"`, create a `TextureRect` (hidden, off-screen)
   and a CEF browser targeting it
3. Each frame, grab the `TextureRect`'s texture and assign it to
   `warp_polygon.texture`
4. The existing UV mapping and warp pipeline handles the rest

### Surface Data Model Extension

```json
{
  "content_type": "web",
  "web_url": "http://localhost:3000",
  "web_refresh_rate": 30
}
```

### Sidebar UI Addition

- Content type dropdown: Solid Color | Test Pattern | Web URL
- When "Web URL" selected, show a `LineEdit` for the URL
- Optional: refresh rate slider (15-60 fps)
- Optional: resolution selector (the CEF browser viewport size)

### Files to Modify

| File | Changes |
|------|---------|
| `scripts/projection_surface.gd` | Add CEF browser creation, texture piping |
| `scripts/sidebar.gd` | Add URL input field when content type is "web" |
| `autoload/surface_manager.gd` | Add `content_type`, `web_url` to surface dict |
| `autoload/surface_manager.gd` | Extend save/load for new fields |

---

## Alternative: HTTP Screenshot Polling (No Xcode Needed)

If GDCEf proves too heavy or the build keeps failing, a lighter approach:

1. Run a sidecar (Node.js + Puppeteer) that screenshots a URL periodically
2. Serve the screenshot over `http://localhost:9999/screenshot.png`
3. In Godot, use `HTTPRequest` + `Image.load_png_from_buffer()` on a timer
4. Assign the resulting `ImageTexture` to the surface

This gives ~10-30 FPS with no native dependencies, but no interactivity.

### Quick Sidecar Script (Node.js)

```javascript
// sidecar/screenshot-server.js
const puppeteer = require('puppeteer');
const http = require('http');

const TARGET_URL = process.argv[2] || 'http://localhost:3000';
const PORT = 9999;
let latestScreenshot = null;

(async () => {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });
  await page.goto(TARGET_URL);

  setInterval(async () => {
    latestScreenshot = await page.screenshot({ type: 'png' });
  }, 100); // ~10 FPS

  http.createServer((req, res) => {
    if (latestScreenshot) {
      res.writeHead(200, { 'Content-Type': 'image/png' });
      res.end(latestScreenshot);
    } else {
      res.writeHead(503);
      res.end('Not ready');
    }
  }).listen(PORT);

  console.log(`Screenshot server on :${PORT} for ${TARGET_URL}`);
})();
```

---

## Build Script Location & Key Config

- **Build script:** `external/gdcef/build.py`
- **Godot version:** Line 68 — `GODOT_VERSION = "4.5"`
- **CEF version:** Line 65 — `CEF_VERSION = "..."` (auto-detected)
- **Output:** `external/gdcef/cef_artifacts/`
- **Python requirements:** `external/gdcef/requirements.txt`

---

*Resume this guide after installing Xcode.*
