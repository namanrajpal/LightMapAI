# v1 — Projection Mapping MVP: Implementation Plan

> **Target Display:** Nomvdic PJ · 3840×2160 native · macOS exposes 1920×1080 @ 60 Hz
> **Engine:** Godot 4.x · GDScript · `canvas_items` stretch mode
> **Date:** 2026-04-02

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Core Concepts](#2-core-concepts)
3. [Feature Breakdown](#3-feature-breakdown)
4. [UI Layout](#4-ui-layout)
5. [Technical Approach](#5-technical-approach)
6. [File Structure](#6-file-structure)
7. [Data Schema](#7-data-schema)
8. [Keyboard Shortcuts](#8-keyboard-shortcuts)
9. [Implementation Phases](#9-implementation-phases)
10. [Acceptance Criteria](#10-acceptance-criteria)

---

## 1. Architecture Overview

The application has **two runtime modes**:

| Mode | Purpose | UI Visible |
|------|---------|------------|
| **Setup Mode** | Calibration, surface editing, test patterns | Sidebar + toolbar + status bar + corner handles + grid overlays |
| **Output Mode** | Clean projection output | Only warped surfaces — all chrome hidden |

A single keypress (F11 or Tab) toggles between modes. The Godot window can be dragged to the projector display before entering Output Mode for live projection.

### High-Level Node Tree

```
Root (Control – full window)
├── App (HSplitContainer)
│   ├── Sidebar (PanelContainer)
│   │   ├── Toolbar (HBoxContainer)
│   │   └── SurfaceList (VBoxContainer, scrollable)
│   └── ProjectionCanvas (SubViewportContainer)
│       └── SubViewport
│           ├── Surface_1 (projection_surface.tscn)
│           │   ├── WarpedQuad (Polygon2D + shader)
│           │   ├── GridOverlay (Polygon2D + shader)
│           │   └── CornerHandles × 4
│           ├── Surface_2 …
│           └── …
├── StatusBar (PanelContainer)
└── Autoloads
    └── SurfaceManager (singleton)
```

---

## 2. Core Concepts

### Surface

A **Surface** is the fundamental primitive — a quad defined by 4 corner positions that can be independently warped to match physical wall geometry.

```
Surface {
  id:        String (UUID)
  label:     String ("Surface 1")
  color:     Color
  corners:   PackedVector2Array  # TL, TR, BR, BL in canvas coords
  z_index:   int
  visible:   bool
  grid_on:   bool
  locked:    bool
}
```

### Warp

Each surface renders its content (solid color, test pattern, or future media) through a **perspective-warp shader**. The shader maps the 4 source corners (a rectangle) onto the 4 destination corners (an arbitrary convex quad), producing keystone correction.

### Corner Handle

A small draggable control node positioned at each corner of a surface. Supports:
- **Mouse drag** for coarse positioning
- **Arrow keys** for pixel-precise nudging (when selected)
- **Visual feedback** — changes color when hovered/selected

---

## 3. Feature Breakdown

### 3.1 Quad / Keystone Warping

- 4 draggable corners per surface define the warp quad
- `perspective_warp.gdshader` performs bilinear or projective interpolation
- Shader uniforms receive the 4 corner positions every frame corners move
- Fine-tuning: arrow keys nudge the selected corner by 1 px (Shift+arrow = 10 px)

### 3.2 Multiple Surfaces

- Create / delete surfaces from the sidebar
- Click a surface on canvas or in sidebar to select it
- Selected surface shows corner handles and highlighted border
- Each surface carries its own color, label, warp state, and z-order
- Z-order adjustable (move forward / move back buttons)
- Surfaces may overlap

### 3.3 Setup / Calibration Mode

| Feature | Description |
|---------|-------------|
| **Grid Overlay** | Toggleable per-surface grid rendered by `grid_overlay.gdshader` |
| **Test Patterns** | Dropdown: Checkerboard, Crosshair, Color Bars, White Flood |
| **Surface Outline** | Dashed border around selected quad with corner labels (TL, TR, BR, BL) |
| **Info Panel** | Real-time readout of each corner's (x, y) in the status bar |

### 3.4 Fullscreen Output

- **F11** or **Tab** toggles Output Mode
- Hides sidebar, toolbar, status bar, corner handles, grid overlays
- Shows only the warped surface content
- **Esc** returns to Setup Mode
- Intended workflow: drag window to projector → enter Output Mode

### 3.5 Save / Load Configurations

- Serializes all surfaces (positions, colors, labels, z-order, grid state) to JSON
- Default path: `user://configs/` (maps to OS app-data)
- Toolbar buttons: **Save**, **Load**, **Save As**
- Shortcuts: `Ctrl+S` (save), `Ctrl+O` (load)
- On first launch, loads `default_config.json` if it exists

---

## 4. UI Layout

```
┌──────────────────────────────────────────────────────────────┐
│ Toolbar: [+ Add] [Test Pattern ▾] [Grid ☐] [Save] [Load]   │
│          [Output Mode ▶]                                     │
├──────────────┬───────────────────────────────────────────────┤
│   Sidebar    │                                               │
│   (250 px)   │         Projection Canvas                     │
│              │                                               │
│  ┌─────────┐ │    ┌─────────────────────┐                    │
│  │Surface 1│ │    │   Surface 1 (warped) │                   │
│  │ Color ■ │ │    │    with grid overlay │                   │
│  │ Label   │ │    └─────────────────────┘                    │
│  │ Z: 0    │ │              ┌──────────────┐                 │
│  │ [🔒][🗑]│ │              │  Surface 2   │                 │
│  └─────────┘ │              └──────────────┘                 │
│  ┌─────────┐ │                                               │
│  │Surface 2│ │     ● Corner handles visible                  │
│  │ ...     │ │       when surface selected                   │
│  └─────────┘ │                                               │
│              │                                               │
│  [+ Add]     │                                               │
├──────────────┴───────────────────────────────────────────────┤
│ Status: Surface 1 selected │ TL(120,80) TR(500,85)          │
│                            │ BL(115,400) BR(505,395)         │
└──────────────────────────────────────────────────────────────┘
```

---

## 5. Technical Approach

### 5.1 Perspective Warp Shader (`perspective_warp.gdshader`)

The shader takes 4 `vec2` uniforms (`corner_tl`, `corner_tr`, `corner_br`, `corner_bl`) representing UV-space destination positions and performs a **projective texture mapping**.

**Algorithm outline:**

1. For each fragment, compute the inverse bilinear interpolation to find the UV coordinate that maps from the deformed quad back to the unit square.
2. Sample the surface's color / texture at that UV.
3. Discard fragments outside the quad.

```glsl
shader_type canvas_item;

uniform vec2 corner_tl = vec2(0.0, 0.0);
uniform vec2 corner_tr = vec2(1.0, 0.0);
uniform vec2 corner_br = vec2(1.0, 1.0);
uniform vec2 corner_bl = vec2(0.0, 1.0);
uniform vec4 surface_color : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform sampler2D surface_texture : hint_default_white;
uniform bool use_texture = false;

// Inverse bilinear interpolation to find (u,v) from screen position
// Uses the technique from "Fundamentals of Texture Mapping and Image Warping" (Heckbert 1989)

void fragment() {
    // Implementation: project screen-space position back through
    // the perspective transform defined by the 4 corners
    // ... (full math in implementation)
    
    vec2 uv = /* computed UV */;
    
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        discard;
    }
    
    if (use_texture) {
        COLOR = texture(surface_texture, uv);
    } else {
        COLOR = surface_color;
    }
}
```

> **Implementation note:** The actual shader will use a full projective (homography) approach. The 3×3 homography matrix `H` maps unit-square UVs to quad corners. We compute `H⁻¹` on the CPU (GDScript) each time corners change and pass it as a `mat3` uniform, which is more efficient than per-pixel inverse bilinear.

### 5.2 Grid Overlay Shader (`grid_overlay.gdshader`)

Renders a customizable grid within the warped quad:

```glsl
shader_type canvas_item;

uniform float grid_spacing = 0.1;  // 10 divisions
uniform float line_width = 0.003;
uniform vec4 grid_color : source_color = vec4(1.0, 1.0, 1.0, 0.4);

void fragment() {
    vec2 uv = UV;
    float gx = abs(fract(uv.x / grid_spacing + 0.5) - 0.5);
    float gy = abs(fract(uv.y / grid_spacing + 0.5) - 0.5);
    float line = min(gx, gy);
    
    if (line < line_width) {
        COLOR = grid_color;
    } else {
        COLOR = vec4(0.0);
    }
}
```

### 5.3 Corner Handles

Each corner handle is a lightweight `Control` node:

- **Size:** 16×16 px (scalable)
- **Rendering:** Custom `_draw()` — circle with outline
- **Interaction:**
  - `_gui_input()` handles mouse drag (sets `corner` position in parent surface)
  - Keyboard input (arrow keys) handled when focused
  - Emits `corner_moved(corner_index: int, new_position: Vector2)` signal

### 5.4 Surface Manager (Autoload Singleton)

Central data store and coordinator:

```gdscript
# surface_manager.gd — Autoload

var surfaces: Array[Dictionary] = []
var selected_surface_id: String = ""

signal surface_added(id: String)
signal surface_removed(id: String)
signal surface_selected(id: String)
signal surface_updated(id: String)
signal mode_changed(is_output: bool)

func add_surface() -> String: ...
func remove_surface(id: String) -> void: ...
func select_surface(id: String) -> void: ...
func get_surface(id: String) -> Dictionary: ...
func update_corners(id: String, corners: PackedVector2Array) -> void: ...
func set_output_mode(enabled: bool) -> void: ...
func save_config(path: String) -> void: ...
func load_config(path: String) -> void: ...
func generate_id() -> String: ...
```

### 5.5 Godot Project Settings Changes

| Setting | Value | Reason |
|---------|-------|--------|
| `display/window/size/viewport_width` | `1920` | Match projector logical resolution |
| `display/window/size/viewport_height` | `1080` | Match projector logical resolution |
| `display/window/stretch/mode` | `canvas_items` | Scale UI to any display |
| `display/window/stretch/aspect` | `keep` | Maintain 16:9 aspect |
| `rendering/renderer/rendering_method` | `gl_compatibility` | Best 2D perf, widest compat |
| `application/run/main_scene` | `res://scenes/app.tscn` | New main scene |
| `autoload/SurfaceManager` | `res://autoload/surface_manager.gd` | Singleton |

---

## 6. File Structure

```
res://
├── project.godot                        # Modified settings
├── plans/
│   └── v1-projection-mapping-mvp.md     # This document
├── autoload/
│   └── surface_manager.gd              # Singleton: surface CRUD, selection, serialization
├── scenes/
│   ├── app.tscn                         # Root scene: sidebar + canvas + toolbar + status
│   ├── projection_surface.tscn          # Instanced per-surface: warp quad + grid + handles
│   └── corner_handle.tscn              # Reusable draggable corner control
├── scripts/
│   ├── app.gd                           # Main app controller, mode toggling, keybinds
│   ├── projection_canvas.gd             # Canvas area: manages surface instances
│   ├── projection_surface.gd            # Surface logic: warp math, shader updates, grid
│   ├── corner_handle.gd                 # Drag + nudge behavior for one corner
│   ├── sidebar.gd                       # Sidebar UI: surface list, add/remove, property editing
│   ├── toolbar.gd                       # Top toolbar: test patterns, save/load, mode toggle
│   └── status_bar.gd                   # Bottom bar: selected surface info, corner coords
├── shaders/
│   ├── perspective_warp.gdshader        # Projective homography warp
│   └── grid_overlay.gdshader            # Calibration grid lines
├── resources/
│   └── test_patterns/
│       ├── checkerboard.png             # 512×512 procedural checkerboard
│       ├── color_bars.png               # SMPTE-style color bars
│       └── crosshair.png               # Center crosshair with rule lines
└── data/
    └── default_config.json              # Ships with one centered surface
```

### Files from existing project (to modify or replace)

| File | Action |
|------|--------|
| `project.godot` | **Modify** — update viewport size, stretch mode, main scene, add autoload |
| `main.tscn` | **Keep** as backup, no longer the main scene |
| `icon_movement.gd` | **Keep** — unused by new app but harmless |

---

## 7. Data Schema

### `config.json` — Save File Format

```json
{
  "version": 1,
  "app": {
    "canvas_size": [1920, 1080]
  },
  "surfaces": [
    {
      "id": "a1b2c3d4",
      "label": "Surface 1",
      "color": "#3380FF",
      "z_index": 0,
      "visible": true,
      "locked": false,
      "grid_on": false,
      "corners": {
        "tl": [200, 100],
        "tr": [600, 100],
        "br": [600, 500],
        "bl": [200, 500]
      }
    },
    {
      "id": "e5f6g7h8",
      "label": "Surface 2",
      "color": "#FF8033",
      "z_index": 1,
      "visible": true,
      "locked": false,
      "grid_on": true,
      "corners": {
        "tl": [700, 150],
        "tr": [1100, 160],
        "br": [1120, 550],
        "bl": [690, 540]
      }
    }
  ]
}
```

### `default_config.json` — Ships with project

One centered surface, axis-aligned (no warp), to give the user something to see on first launch:

```json
{
  "version": 1,
  "app": { "canvas_size": [1920, 1080] },
  "surfaces": [
    {
      "id": "default-1",
      "label": "Surface 1",
      "color": "#4488FF",
      "z_index": 0,
      "visible": true,
      "locked": false,
      "grid_on": true,
      "corners": {
        "tl": [460, 240],
        "tr": [1460, 240],
        "br": [1460, 840],
        "bl": [460, 840]
      }
    }
  ]
}
```

---

## 8. Keyboard Shortcuts

| Key | Context | Action |
|-----|---------|--------|
| `F11` or `Tab` | Global | Toggle Setup ↔ Output mode |
| `Esc` | Output Mode | Return to Setup Mode |
| `Arrow Keys` | Corner selected | Nudge corner 1 px |
| `Shift + Arrow` | Corner selected | Nudge corner 10 px |
| `Delete` | Surface selected | Delete selected surface |
| `Ctrl + S` | Global | Save configuration |
| `Ctrl + O` | Global | Load configuration |
| `Ctrl + N` | Global | Add new surface |
| `G` | Surface selected | Toggle grid overlay |
| `L` | Surface selected | Toggle lock |
| `]` | Surface selected | Move surface forward (z-order) |
| `[` | Surface selected | Move surface backward (z-order) |
| `1-4` | Surface selected | Select corner (TL=1, TR=2, BR=3, BL=4) |

---

## 9. Implementation Phases

### Phase 1 — Project Scaffolding & Core Data Layer

**Goal:** Set up the project structure, autoload singleton, and data model.

**Files to create/modify:**

| # | File | What to do |
|---|------|------------|
| 1 | `project.godot` | Update viewport size (1920×1080), stretch mode (`canvas_items`), rendering method (`gl_compatibility`), register `SurfaceManager` autoload, set main scene to `res://scenes/app.tscn` |
| 2 | `autoload/surface_manager.gd` | Implement: `surfaces` array, `add_surface()`, `remove_surface()`, `select_surface()`, `get_surface()`, `update_corners()`, `generate_id()`, signals |
| 3 | `data/default_config.json` | Create default config with one centered surface |

**Acceptance:**
- [x] Project runs without errors
- [x] `SurfaceManager` accessible via `SurfaceManager.add_surface()` from any script
- [x] Can add/remove surfaces in code and verify via print

---

### Phase 2 — Perspective Warp Shader

**Goal:** Working perspective warp that distorts a colored quad based on 4 corners.

**Files to create:**

| # | File | What to do |
|---|------|------------|
| 1 | `shaders/perspective_warp.gdshader` | Implement projective homography warp. Accept `mat3 inverse_homography` uniform (computed on CPU). Map fragment position back to UV, sample color/texture, discard out-of-bounds. |
| 2 | `shaders/grid_overlay.gdshader` | Grid-line shader with `grid_spacing`, `line_width`, `grid_color` uniforms. Renders atop the warped surface using the same homography. |

**Acceptance:**
- [ ] A `Polygon2D` with the warp shader shows a colored quad
- [ ] Changing corner uniforms visually distorts the quad in real time
- [ ] Grid lines appear correctly aligned within the warped quad

---

### Phase 3 — Corner Handles & Surface Scene

**Goal:** Draggable corner handles that control the warp in real time.

**Files to create:**

| # | File | What to do |
|---|------|------------|
| 1 | `scenes/corner_handle.tscn` | `Control` node (16×16), script attached |
| 2 | `scripts/corner_handle.gd` | `_gui_input()` for drag, `_unhandled_key_input()` for arrow-key nudge, `corner_moved` signal, custom `_draw()` for circle rendering, hover/selected visual states |
| 3 | `scenes/projection_surface.tscn` | Scene: root `Control` → `Polygon2D` (warp shader) + `Polygon2D` (grid shader) + 4 × `corner_handle.tscn` instances |
| 4 | `scripts/projection_surface.gd` | Manages the 4 handles, computes homography matrix on corner change, updates shader uniforms, connects to `SurfaceManager` signals, handles surface color/label/visibility/grid state |

**Acceptance:**
- [ ] Dragging a corner visually warps the surface in real time
- [ ] Arrow keys nudge corners 1 px (Shift = 10 px)
- [ ] Grid overlay toggles on/off and stays aligned with warp

---

### Phase 4 — Main App Scene & Canvas

**Goal:** Multi-surface canvas with creation/deletion.

**Files to create:**

| # | File | What to do |
|---|------|------------|
| 1 | `scenes/app.tscn` | Root `Control` with `HSplitContainer` (sidebar | canvas area), toolbar `HBoxContainer` at top, `PanelContainer` status bar at bottom |
| 2 | `scripts/app.gd` | Mode toggling (Setup/Output), global keyboard shortcuts dispatch, connects toolbar/sidebar to `SurfaceManager` |
| 3 | `scripts/projection_canvas.gd` | Attached to the canvas area. Listens to `SurfaceManager.surface_added/removed`, instances/frees `projection_surface.tscn`, manages z-ordering, handles click-to-select on surfaces |

**Acceptance:**
- [ ] App launches with sidebar + canvas layout
- [ ] Clicking "Add Surface" creates a new surface on canvas
- [ ] Clicking a surface selects it (highlights border, shows handles)
- [ ] Deleting a surface removes it from canvas and sidebar

---

### Phase 5 — Sidebar, Toolbar, Status Bar

**Goal:** Full UI chrome for Setup Mode.

**Files to create:**

| # | File | What to do |
|---|------|------------|
| 1 | `scripts/sidebar.gd` | Renders a list of surface cards (label, color swatch, z-order, lock/delete buttons). Clicking a card selects the surface. Editable label via `LineEdit`. Color via `ColorPickerButton`. |
| 2 | `scripts/toolbar.gd` | Buttons: Add Surface, Test Pattern dropdown (`OptionButton`), Grid toggle, Save, Load, Output Mode. Connects to `SurfaceManager`. |
| 3 | `scripts/status_bar.gd` | Shows: selected surface name, 4 corner coordinates updating in real time, current mode label. |

**Acceptance:**
- [ ] Sidebar accurately reflects the surface list
- [ ] Changing color/label in sidebar updates the surface on canvas
- [ ] Toolbar buttons all functional
- [ ] Status bar shows live corner coordinates

---

### Phase 6 — Test Patterns

**Goal:** Provide standard calibration patterns.

**Files to create:**

| # | File | What to do |
|---|------|------------|
| 1 | `resources/test_patterns/checkerboard.png` | Generate programmatically (512×512) or include a pre-made asset |
| 2 | `resources/test_patterns/color_bars.png` | SMPTE-style bars |
| 3 | `resources/test_patterns/crosshair.png` | Center cross with quadrant lines |
| 4 | Modify `projection_surface.gd` | Accept a test pattern texture, pass to warp shader's `surface_texture` uniform, toggle `use_texture` |

**Acceptance:**
- [ ] Selecting "Checkerboard" from toolbar applies it to the selected surface
- [ ] Pattern warps correctly with the quad
- [ ] "None" option returns to solid color mode

---

### Phase 7 — Save / Load

**Goal:** Persist and restore full configurations.

**Files to modify:**

| # | File | What to do |
|---|------|------------|
| 1 | `autoload/surface_manager.gd` | Implement `save_config(path)` → serialize `surfaces` array to JSON, `load_config(path)` → parse JSON, recreate surfaces. Handle `user://configs/` directory. |
| 2 | `scripts/toolbar.gd` | Wire Save/Load buttons to file dialog or direct quick-save |
| 3 | `scripts/app.gd` | On `_ready()`, attempt to load `default_config.json`. Register `Ctrl+S` / `Ctrl+O` shortcuts. |

**Acceptance:**
- [ ] Saving writes a valid JSON file to `user://configs/`
- [ ] Loading restores all surfaces exactly
- [ ] Quick-save / quick-load shortcuts work
- [ ] Default config loads on first launch

---

### Phase 8 — Output Mode & Fullscreen

**Goal:** Clean fullscreen projection output.

**Files to modify:**

| # | File | What to do |
|---|------|------------|
| 1 | `scripts/app.gd` | Toggle sidebar, toolbar, status bar visibility. Toggle corner handle visibility on all surfaces. Handle F11/Tab/Esc keybinds. Optionally switch to borderless fullscreen. |
| 2 | `scripts/projection_surface.gd` | Respect output mode — hide grid overlay and corner handles |

**Acceptance:**
- [ ] F11 hides all UI, shows only warped surfaces
- [ ] Esc returns to Setup Mode
- [ ] Surfaces render identically in both modes
- [ ] Works on the projector display at 1920×1080

---

### Phase 9 — Polish & Edge Cases

**Goal:** Smooth out the experience.

| Task | Details |
|------|---------|
| Undo/Redo (optional) | Command pattern for corner moves — stretch goal |
| Surface bounds clamping | Prevent corners from being dragged off-screen |
| Overlap click detection | Click on overlapping surfaces selects the topmost |
| Minimum quad size | Prevent degenerate (self-intersecting) quads |
| Save reminder | Warn on quit if unsaved changes |
| Performance | Profile with 10+ surfaces, optimize shader uniform updates |

---

## 10. Acceptance Criteria (MVP Complete)

The v1 MVP is considered **done** when all of the following are true:

- [ ] User can create multiple warpable surfaces
- [ ] Each surface has 4 draggable corners with pixel-precise nudging
- [ ] Perspective warp shader correctly distorts surfaces
- [ ] Grid overlay aligns within warped quads
- [ ] Sidebar lists all surfaces with editable properties (label, color, z-order)
- [ ] Test patterns (checkerboard, color bars, crosshair) apply to surfaces
- [ ] Output Mode hides all UI chrome; only warped surfaces visible
- [ ] F11/Tab toggles modes; Esc exits Output Mode
- [ ] Save/Load persists all surface data to/from JSON
- [ ] Default config loads on first launch with one centered surface
- [ ] App runs at 60 fps on the target projector (1920×1080)
- [ ] No crashes or errors in normal usage

---

## Appendix A: Homography Math Reference

Given source corners `(0,0), (1,0), (1,1), (0,1)` and destination corners `p0, p1, p2, p3`, the 3×3 homography matrix `H` is computed by solving:

```
H * [u, v, 1]ᵀ = w * [x, y, 1]ᵀ
```

For the shader, we need the **inverse** `H⁻¹` which maps screen coordinates back to UV space. This is computed on the CPU in `projection_surface.gd` whenever corners move:

```gdscript
func _compute_inverse_homography(src: PackedVector2Array, dst: PackedVector2Array) -> Transform2D:
    # src = unit square corners [0,0], [1,0], [1,1], [0,1]
    # dst = the 4 screen-space corner positions
    # Returns the 3x3 inverse homography as shader-compatible values
    # Full implementation uses Gaussian elimination on the 8-equation system
    ...
```

The `mat3` is passed to the shader as 3 `vec3` uniforms (Godot doesn't natively support `mat3` uniforms in canvas shaders, so we pack into 3 vectors).

---

## Appendix B: Projector Setup Workflow

1. Connect projector (Nomvdic PJ) via HDMI
2. macOS → System Settings → Displays → Arrange displays side by side
3. Launch Godot project
4. Drag Godot window to projector display
5. Click **Output Mode** (or press F11)
6. Adjust surfaces using Setup Mode on the laptop display, output updates live on projector

> **Tip:** For dual-screen workflow in a future version, consider using a secondary Godot `Window` node positioned on the projector, while the setup UI stays on the primary display.

---

*End of implementation plan.*
