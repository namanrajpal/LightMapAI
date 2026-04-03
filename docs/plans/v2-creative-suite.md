# v2 — Creative Projection Suite: Feature Plan

> **Prerequisite:** v1 MVP complete (quad warping, multi-surface, save/load, output mode)
> **Engine:** Godot 4.x · GDScript · `canvas_items` stretch mode
> **Date:** 2026-04-02

---

## Table of Contents

1. [Vision](#1-vision)
2. [Feature Tiers](#2-feature-tiers)
3. [Tier 1 — Media & Content](#3-tier-1--media--content)
4. [Tier 2 — Canvas & Workflow](#4-tier-2--canvas--workflow)
5. [Tier 3 — Generative & Effects](#5-tier-3--generative--effects)
6. [Tier 4 — Animation & Show Control](#6-tier-4--animation--show-control)
7. [Tier 5 — Advanced Geometry](#7-tier-5--advanced-geometry)
8. [Tier 6 — Multi-Projector & Dual Display](#8-tier-6--multi-projector--dual-display)
9. [Tier 7 — External Integration](#9-tier-7--external-integration)
10. [Tier 8 — Content Management & Export](#10-tier-8--content-management--export)
11. [Updated Data Schema](#11-updated-data-schema)
12. [Updated File Structure](#12-updated-file-structure)
13. [New Keyboard Shortcuts](#13-new-keyboard-shortcuts)
14. [Implementation Phases](#14-implementation-phases)
15. [Acceptance Criteria](#15-acceptance-criteria)

---

## 1. Vision

v1 gives you a calibration tool — you can warp quads onto walls. v2 turns it into something you'd actually perform with. The goal is a self-contained creative projection suite where you can load media, layer effects, sequence a show, and drive it all live — without leaving Godot.

The features are organized into tiers by dependency and impact. Tiers 1–3 are the core creative upgrade. Tiers 4–8 are progressively more specialized.

---

## 2. Feature Tiers

| Tier | Name | Priority | Depends On |
|------|------|----------|------------|
| 1 | Media & Content | Highest | v1 complete |
| 2 | Canvas & Workflow | Highest | v1 complete |
| 3 | Generative & Effects | High | Tier 1 |
| 4 | Animation & Show Control | High | Tier 1, 3 |
| 5 | Advanced Geometry | Medium | v1 complete |
| 6 | Multi-Projector & Dual Display | Medium | v1 complete |
| 7 | External Integration (OSC/MIDI) | Medium | Tier 4 |
| 8 | Content Management & Export | Low | Tier 1 |

---

## 3. Tier 1 — Media & Content

The single most requested upgrade. Surfaces need to show more than solid colors.

### 3.1 Image Loading

- Load PNG, JPG, WebP, SVG onto any surface
- File picker dialog or drag-and-drop onto surface in canvas
- Per-surface content assignment (sidebar dropdown or drag target)
- Images warp correctly through the existing homography shader

### 3.2 Video Playback

- Load MP4, WebM, OGV via Godot's `VideoStreamPlayer`
- Per-surface transport controls: play, pause, stop, loop, scrub
- Video renders into a `SubViewport` texture fed to the warp shader
- Audio output toggle per surface (mute by default for projection use)

### 3.3 Content Fit Modes

Each surface gets a fit mode controlling how content maps to the quad:

| Mode | Behavior |
|------|----------|
| Stretch | Content fills the entire quad (default, may distort aspect) |
| Fit | Content scales to fit inside quad, letterboxed |
| Fill | Content scales to cover quad, cropped at edges |
| Tile | Content repeats at native resolution |
| Original | Content at 1:1 pixel size, centered |

### 3.4 Content Transform (Pan, Zoom, Rotate)

- Per-surface content offset (x, y) — pan the image within the quad
- Per-surface content scale — zoom in/out
- Per-surface content rotation — rotate content independently of the quad warp
- These transform the UV coordinates before sampling, not the quad geometry
- Sidebar sliders + direct manipulation (Alt+drag to pan, Alt+scroll to zoom)

### 3.5 Per-Surface Opacity

- Opacity slider (0.0–1.0) in the sidebar per surface
- Shader `uniform float opacity` multiplied into final COLOR.a
- Enables fade-in/fade-out effects and layered transparency

### 3.6 Live Camera Feed

- Webcam or capture card as a surface source via Godot's `CameraTexture`
- Camera selection dropdown in sidebar (enumerate available devices)
- Useful for live events, IMAG (image magnification), interactive installations

---

## 4. Tier 2 — Canvas & Workflow

Quality-of-life features that make the tool usable for real projects.

### 4.1 Undo / Redo

- Command pattern: every mutation (corner move, property change, add/delete surface) creates a command object
- `Ctrl+Z` undo, `Ctrl+Shift+Z` redo
- Stack depth: 100 operations
- Commands stored in `UndoManager` autoload

```gdscript
# autoload/undo_manager.gd

class Command:
    func execute() -> void: pass
    func undo() -> void: pass
    func description() -> String: return ""

class MoveCornerCommand extends Command:
    var surface_id: String
    var corner_index: int
    var old_position: Vector2
    var new_position: Vector2
    # ...

var undo_stack: Array[Command] = []
var redo_stack: Array[Command] = []
const MAX_STACK = 100

func do(cmd: Command) -> void: ...
func undo() -> void: ...
func redo() -> void: ...
```

### 4.2 Canvas Zoom & Pan

- Scroll wheel zooms the projection canvas (0.25x – 4.0x)
- Middle mouse button drag pans the canvas
- `Ctrl+0` resets to 1:1 zoom, fit-to-window
- Zoom level shown in status bar
- Corner handles scale inversely so they stay usable at any zoom level
- Implemented via `Camera2D` on the canvas SubViewport or transform on the canvas container

### 4.3 Multi-Select

- `Shift+Click` adds surfaces to selection
- `Ctrl+A` selects all surfaces
- Drag-select (rubber band) on empty canvas area
- Multi-selected surfaces can be moved together (drag any selected surface)
- Delete key removes all selected surfaces
- Sidebar highlights all selected surface cards

### 4.4 Surface Duplication

- `Ctrl+D` duplicates selected surface(s) with a small offset (+20px, +20px)
- Duplicated surface gets a new ID, label appended with "(copy)"
- All properties cloned: corners, color, content, opacity, z-order

### 4.5 Alignment Guides & Snapping

- Surfaces snap to edges of other surfaces when dragging corners (8px threshold)
- Snap to canvas center lines (horizontal and vertical)
- Hold `Alt` while dragging to temporarily disable snapping
- Visual guide lines appear during snap (thin colored lines)

---

## 5. Tier 3 — Generative & Effects

Turn surfaces into dynamic canvases.

### 5.1 Built-in Shader Effects Library

A set of ready-to-use fragment shaders that can be assigned as surface content:

| Effect | Description | Key Parameters |
|--------|-------------|----------------|
| Solid Color | Flat fill (v1 default) | color |
| Gradient | Linear/radial gradient | color_a, color_b, angle, type |
| Noise | Animated Perlin/Simplex noise | speed, scale, color_a, color_b |
| Plasma | Classic plasma effect | speed, complexity, palette |
| Color Cycle | Hue rotation over time | speed, saturation, brightness |
| Strobe | Flashing on/off | frequency, color, duty_cycle |
| Wave | Sine wave distortion | amplitude, frequency, speed, axis |
| Kaleidoscope | Mirror/repeat pattern | segments, rotation, zoom |

Each effect is a `.gdshader` file in `shaders/effects/`. The sidebar shows a dropdown to pick the effect, and sliders for its parameters are auto-generated from the shader uniforms.

### 5.2 Effect Stacking (Layers per Surface)

- Each surface has an ordered list of content layers
- Layer types: Solid Color, Image, Video, Camera, Shader Effect
- Layers composite top-to-bottom with blend modes
- Blend modes: Normal, Add, Multiply, Screen, Overlay, Difference
- Per-layer opacity
- Layers render into a per-surface `SubViewport`, which feeds the warp shader

```
Surface
├── Layer 0: Image (background.jpg) — Normal, 100%
├── Layer 1: Shader Effect (noise) — Add, 40%
└── Layer 2: Text ("HELLO") — Normal, 80%
```

### 5.3 Text Rendering

- Add text as a layer on any surface
- Properties: content string, font (system or loaded .ttf/.otf), size, color, alignment
- Scrolling marquee mode (horizontal/vertical, speed)
- Outline and shadow options
- Rendered via Godot `Label` or `RichTextLabel` inside the surface's SubViewport

### 5.4 Audio-Reactive Mode

- Microphone input or audio file as analysis source
- FFT analysis extracts: bass, mid, treble energy levels (0.0–1.0)
- Beat detection (onset detection algorithm)
- These values exposed as shader uniforms on any effect layer:
  - `audio_bass`, `audio_mid`, `audio_treble`, `audio_beat`
- Example: noise shader `scale` driven by `audio_bass`, strobe triggered by `audio_beat`
- Audio source selection in toolbar (mic, file, or disabled)
- Sensitivity / gain slider

### 5.5 Particle Systems

- Add a `GPUParticles2D` as a layer type on any surface
- Presets: fire, rain, snow, sparks, confetti, smoke
- Key parameters exposed in sidebar: amount, lifetime, speed, spread, color gradient
- Particles render inside the surface SubViewport, so they warp with the quad

---

## 6. Tier 4 — Animation & Show Control

Go from static mapping to live performance.

### 6.1 Property Keyframing

- Timeline panel at the bottom of the screen (collapsible, hidden in Output Mode)
- Keyframeable properties per surface: opacity, color, content offset/scale/rotation, shader params
- Linear and eased interpolation between keyframes
- Timeline duration adjustable (seconds or bars if BPM synced)
- Playback: play, pause, stop, loop, scrub
- Multiple timelines (scenes/cues) that can be switched

### 6.2 Transitions

Animated transitions when switching content or cues:

| Transition | Description |
|------------|-------------|
| Cut | Instant switch |
| Fade | Cross-dissolve over duration |
| Wipe | Directional reveal (left, right, up, down, diagonal) |
| Dissolve | Random pixel dissolve |
| Zoom | Scale in/out |

- Transition type and duration configurable per cue change
- Implemented as a shader pass that blends old and new content

### 6.3 Cue List / Show Sequencer

- Ordered list of "cues" — each cue is a snapshot of all surface states
- Advance cues with: Spacebar, right arrow, OSC trigger, or auto-advance after duration
- Cue list panel in sidebar (collapsible)
- Each cue stores: surface visibility, content, opacity, shader params, timeline state
- Cue transitions: per-cue transition type and duration
- "Go" button + keyboard shortcut for live performance

```
Cue List:
  1. "Intro"        — Surface 1: blue gradient, Surface 2: hidden     [5s auto]
  2. "Main Visual"  — Surface 1: video loop, Surface 2: noise effect  [manual]
  3. "Climax"       — All surfaces: strobe + audio reactive            [manual]
  4. "Blackout"     — All surfaces: opacity 0                          [3s fade]
```

### 6.4 BPM Sync

- Tap tempo button (tap spacebar or dedicated key to set BPM)
- Manual BPM entry field
- Animations and effects can lock to beat divisions (1/1, 1/2, 1/4, 1/8)
- Beat counter shown in status bar
- Strobe, color cycle, and other effects auto-sync to BPM when enabled

---

## 7. Tier 5 — Advanced Geometry

Beyond simple quads.

### 7.1 Triangle Surfaces

- 3-corner variant of the quad surface
- Useful for mapping triangular architectural features
- Same warp shader approach but with barycentric coordinates instead of homography

### 7.2 Bezier / Curved Edge Warping

- Each edge of a quad gets an optional bezier control point
- The quad mesh is subdivided (e.g., 16×16 grid) and vertices displaced along the curves
- Allows mapping onto curved surfaces (columns, arches, barrel vaults)
- Control points draggable like corner handles, with tangent lines shown

### 7.3 Grid Warp (Mesh Subdivision)

- Subdivide a quad into an N×M mesh (e.g., 8×8)
- Each interior vertex is independently draggable
- Enables organic, non-planar surface mapping
- Useful for fabric, uneven walls, complex architectural features
- Toggle between "quad mode" (4 corners) and "mesh mode" (N×M grid)

### 7.4 Surface Grouping

- Select multiple surfaces → right-click → "Group"
- Grouped surfaces move, scale, and rotate together
- Group has its own transform (offset, scale, rotation) applied on top of individual surface transforms
- Ungroup to return to individual editing
- Groups can be nested

### 7.5 Surface Cloning / Array Tool

- Clone a surface N times with configurable offset (x, y) between copies
- Useful for repetitive patterns (e.g., a row of windows, a grid of tiles)
- Clones can be linked (change one, all update) or independent

### 7.6 Blackout Zones / Masking

- Draw arbitrary polygon masks on the canvas
- Masked regions render as black (no light output)
- Useful for blocking projection onto windows, doors, obstacles, audience areas
- Masks are independent of surfaces and sit on top in z-order

---

## 8. Tier 6 — Multi-Projector & Dual Display

Scale beyond a single projector.

### 8.1 Dual Window Mode

- Setup UI renders on the primary display (laptop screen)
- A second Godot `Window` node opens on the projector display
- The output window shows only warped surfaces (equivalent to Output Mode)
- Setup changes reflect live on the output window
- Window assignment: dropdown to select which display gets the output window

```gdscript
# Dual window approach
var output_window := Window.new()
output_window.title = "Projection Output"
output_window.current_screen = projector_screen_index
output_window.mode = Window.MODE_FULLSCREEN
add_child(output_window)
# Render surfaces into output_window's SubViewport
```

### 8.2 Edge Blending

- For overlapping projector regions, soft-edge blending feathers the overlap
- Per-surface edge blend settings: left, right, top, bottom blend width (pixels)
- Blend curve: linear or gamma-corrected (adjustable gamma value)
- Blend rendered as a gradient alpha mask multiplied into the surface output
- Visual preview in Setup Mode showing the blend zones

### 8.3 Projector Profiles

- Save per-projector calibration: color temperature, brightness, gamma, geometric offset
- Profile assigned to an output window
- Compensates for differences between projector models in multi-projector setups
- Color correction shader applied as a post-process on the output window

---

## 9. Tier 7 — External Integration

Connect to the wider show-control ecosystem.

### 9.1 OSC (Open Sound Control) Input

- Listen on configurable UDP port (default 8000)
- Map incoming OSC addresses to surface properties:
  - `/surface/1/opacity` → float 0.0–1.0
  - `/surface/1/color` → RGB values
  - `/cue/go` → advance cue list
  - `/cue/goto` → jump to specific cue number
- OSC learn mode: click a parameter, send an OSC message, auto-maps
- Compatible with TouchOSC, QLab, Ableton Live, Max/MSP, etc.

### 9.2 MIDI Input

- Enumerate available MIDI devices
- Map MIDI CC (continuous controller) to surface properties (opacity, shader params)
- Map MIDI notes to cue triggers
- MIDI learn mode: click parameter, move knob/press key, auto-maps
- Supports any class-compliant MIDI controller (Akai APC, Novation Launchpad, etc.)

### 9.3 DMX / Art-Net Output (Stretch Goal)

- Send Art-Net (DMX over UDP) to control external lighting fixtures
- Per-cue DMX state: channel values 0–255
- Synchronize lighting changes with projection cue transitions
- Universe and channel configuration in settings

### 9.4 Timecode Sync (Stretch Goal)

- Receive SMPTE/MTC timecode via MIDI
- Lock timeline playback to external timecode source
- Enables frame-accurate synchronization with video playback systems, audio DAWs
- Timecode display in status bar

---

## 10. Tier 8 — Content Management & Export

Organize and share.

### 10.1 Asset Library Panel

- Panel (tab in sidebar or separate dock) showing thumbnails of all imported media
- Categories: Images, Videos, Shaders, Test Patterns
- Drag-and-drop from library onto a surface to assign content
- Search / filter by name
- Shows file size, dimensions, duration (for video)

### 10.2 Project Packaging

- Export a config + all referenced media assets as a single `.zip` bundle
- Import a bundle to restore the full project on another machine
- Resolves relative paths so bundles are portable

### 10.3 Output Recording

- Record the output window to a video file (MP4 via Godot's built-in or FFmpeg)
- Useful for documentation, previews, or pre-rendered playback
- Start/stop recording button in toolbar
- Resolution and framerate settings

### 10.4 Layout Export

- Export surface layout as SVG or PDF
- Shows quad outlines with labels, dimensions, corner coordinates
- Useful for planning, documentation, sharing with venue technicians

---

## 11. Updated Data Schema

The v2 config extends v1. All v1 fields remain, new fields are additive.

```json
{
  "version": 2,
  "app": {
    "canvas_size": [1920, 1080],
    "bpm": 120,
    "audio_source": "microphone"
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
      "opacity": 1.0,
      "corners": {
        "tl": [200, 100],
        "tr": [600, 100],
        "br": [600, 500],
        "bl": [200, 500]
      },
      "content": {
        "fit_mode": "stretch",
        "offset": [0, 0],
        "scale": 1.0,
        "rotation": 0.0
      },
      "layers": [
        {
          "type": "image",
          "source": "res://assets/my_image.png",
          "blend_mode": "normal",
          "opacity": 1.0
        },
        {
          "type": "shader_effect",
          "effect": "noise",
          "params": { "speed": 0.5, "scale": 3.0 },
          "blend_mode": "add",
          "opacity": 0.4
        }
      ],
      "edge_blend": {
        "left": 0, "right": 0, "top": 0, "bottom": 0,
        "gamma": 2.2
      },
      "geometry_mode": "quad",
      "mesh_subdivisions": [1, 1],
      "bezier_edges": null,
      "group_id": null
    }
  ],
  "cues": [
    {
      "id": "cue-1",
      "label": "Intro",
      "auto_advance": true,
      "duration": 5.0,
      "transition": { "type": "fade", "duration": 1.0 },
      "surface_states": {
        "a1b2c3d4": {
          "visible": true,
          "opacity": 1.0,
          "layer_overrides": {}
        }
      }
    }
  ],
  "osc_mappings": [
    {
      "address": "/surface/1/opacity",
      "target_surface": "a1b2c3d4",
      "target_property": "opacity"
    }
  ],
  "midi_mappings": [
    {
      "channel": 1,
      "cc": 1,
      "target_surface": "a1b2c3d4",
      "target_property": "opacity"
    }
  ],
  "blackout_zones": [
    {
      "id": "mask-1",
      "label": "Window Mask",
      "polygon": [[100, 200], [300, 200], [300, 400], [100, 400]]
    }
  ]
}
```

---

## 12. Updated File Structure

New files added on top of the v1 structure:

```
res://
├── autoload/
│   ├── surface_manager.gd              # Extended: layers, content, opacity, groups
│   ├── undo_manager.gd                 # NEW: command pattern undo/redo
│   ├── audio_analyzer.gd               # NEW: FFT analysis, beat detection
│   ├── osc_server.gd                   # NEW: OSC UDP listener + dispatch
│   ├── midi_manager.gd                 # NEW: MIDI device enumeration + CC mapping
│   ├── cue_manager.gd                  # NEW: cue list, transitions, sequencing
│   └── bpm_manager.gd                  # NEW: tap tempo, BPM sync, beat clock
├── scenes/
│   ├── app.tscn                         # Extended: timeline panel, asset library tab
│   ├── projection_surface.tscn          # Extended: SubViewport for layer compositing
│   ├── corner_handle.tscn
│   ├── output_window.tscn              # NEW: secondary window for projector output
│   ├── timeline_panel.tscn             # NEW: keyframe timeline UI
│   ├── cue_list_panel.tscn             # NEW: cue list sidebar panel
│   └── asset_library_panel.tscn        # NEW: media browser panel
├── scripts/
│   ├── app.gd                           # Extended: dual window, zoom/pan, multi-select
│   ├── projection_canvas.gd             # Extended: zoom, pan, rubber-band select, snapping
│   ├── projection_surface.gd            # Extended: layers, content transform, edge blend
│   ├── corner_handle.gd
│   ├── sidebar.gd                       # Extended: layer list, content controls, opacity
│   ├── toolbar.gd                       # Extended: audio source, BPM, record button
│   ├── status_bar.gd                    # Extended: zoom level, BPM, beat counter
│   ├── timeline_panel.gd               # NEW: keyframe editing, playback controls
│   ├── cue_list_panel.gd               # NEW: cue CRUD, go button, transitions
│   ├── asset_library_panel.gd           # NEW: thumbnail grid, drag-and-drop
│   ├── output_window.gd                # NEW: secondary window rendering
│   ├── layer_compositor.gd             # NEW: composites layers into SubViewport
│   └── blackout_zone.gd               # NEW: polygon mask rendering
├── shaders/
│   ├── perspective_warp.gdshader        # Extended: opacity uniform
│   ├── grid_overlay.gdshader
│   ├── edge_blend.gdshader             # NEW: soft-edge gradient for projector overlap
│   ├── transition_fade.gdshader        # NEW: cross-dissolve transition
│   ├── transition_wipe.gdshader        # NEW: directional wipe
│   └── effects/
│       ├── gradient.gdshader            # NEW
│       ├── noise.gdshader               # NEW
│       ├── plasma.gdshader              # NEW
│       ├── color_cycle.gdshader         # NEW
│       ├── strobe.gdshader              # NEW
│       ├── wave.gdshader                # NEW
│       └── kaleidoscope.gdshader        # NEW
└── assets/                              # NEW: user-imported media
    ├── images/
    └── videos/
```

---

## 13. New Keyboard Shortcuts

Additions to the v1 shortcut table:

| Key | Context | Action |
|-----|---------|--------|
| `Ctrl+Z` | Global | Undo |
| `Ctrl+Shift+Z` | Global | Redo |
| `Ctrl+D` | Surface selected | Duplicate surface |
| `Ctrl+A` | Global | Select all surfaces |
| `Ctrl+0` | Canvas | Reset zoom to fit |
| `Scroll Wheel` | Canvas | Zoom in/out |
| `Middle Mouse Drag` | Canvas | Pan canvas |
| `Alt+Drag` | Surface selected | Pan content within surface |
| `Alt+Scroll` | Surface selected | Zoom content within surface |
| `Space` | Cue list active | Go (advance to next cue) |
| `Ctrl+G` | Multi-select | Group selected surfaces |
| `Ctrl+Shift+G` | Group selected | Ungroup |
| `T` | Global | Toggle timeline panel |
| `R` | Global | Start/stop recording |

---

## 14. Implementation Phases

### Phase A — Media Surfaces (Tier 1 core)

**Goal:** Images and video on surfaces with fit modes and opacity.

| # | Task |
|---|------|
| 1 | Extend `projection_surface.gd` to accept a `Texture2D` or `VideoStreamPlayer` as content source |
| 2 | Add `SubViewport` per surface for content compositing |
| 3 | Implement fit modes (stretch, fit, fill, tile, original) as UV transform logic |
| 4 | Add content transform controls (offset, scale, rotation) to sidebar |
| 5 | Add opacity uniform to warp shader, wire to sidebar slider |
| 6 | Add file picker for image/video assignment |
| 7 | Extend save/load to persist content paths, fit mode, opacity, transforms |

**Acceptance:**
- [ ] Can load a PNG onto a surface and it warps correctly
- [ ] Can play a video on a surface with loop
- [ ] Fit modes visually correct
- [ ] Opacity slider fades surface smoothly
- [ ] Content transform (pan/zoom/rotate) works within the warped quad

---

### Phase B — Canvas UX (Tier 2)

**Goal:** Undo/redo, zoom/pan, multi-select, snapping.

| # | Task |
|---|------|
| 1 | Implement `UndoManager` autoload with command pattern |
| 2 | Wrap all mutations (corner move, property change, add/delete) in commands |
| 3 | Add `Camera2D` or transform-based zoom/pan to projection canvas |
| 4 | Implement rubber-band multi-select |
| 5 | Implement alignment snapping (edge-to-edge, center lines) |
| 6 | Add surface duplication |

**Acceptance:**
- [ ] `Ctrl+Z` / `Ctrl+Shift+Z` undo/redo all operations
- [ ] Canvas zooms smoothly with scroll wheel, pans with middle mouse
- [ ] Multi-select works, grouped move works
- [ ] Snapping guides appear and surfaces snap to edges

---

### Phase C — Shader Effects & Layers (Tier 3)

**Goal:** Generative content and layer compositing.

| # | Task |
|---|------|
| 1 | Create the 8 effect shaders in `shaders/effects/` |
| 2 | Build `layer_compositor.gd` — renders layer stack into surface SubViewport |
| 3 | Add layer list UI in sidebar (per surface) with add/remove/reorder |
| 4 | Implement blend modes in the compositor |
| 5 | Add text layer type (Label in SubViewport) |
| 6 | Implement audio analyzer autoload (FFT, beat detection) |
| 7 | Wire audio values to shader uniforms |

**Acceptance:**
- [ ] Can stack image + shader effect + text on one surface
- [ ] Blend modes visually correct
- [ ] Audio-reactive mode drives shader parameters from mic input
- [ ] Effect parameter sliders update shaders in real time

---

### Phase D — Show Control (Tier 4)

**Goal:** Timeline, cues, BPM sync.

| # | Task |
|---|------|
| 1 | Build timeline panel UI (collapsible, keyframe tracks) |
| 2 | Implement keyframe interpolation engine |
| 3 | Build cue list panel and `CueManager` autoload |
| 4 | Implement cue transitions (fade, wipe, dissolve) |
| 5 | Build `BpmManager` with tap tempo |
| 6 | Wire BPM to animation timing and effect parameters |

**Acceptance:**
- [ ] Can keyframe opacity over time and play it back
- [ ] Cue list advances with spacebar, transitions smoothly
- [ ] BPM tap tempo works, effects sync to beat

---

### Phase E — Advanced Geometry (Tier 5)

**Goal:** Bezier edges, mesh warp, masking.

| # | Task |
|---|------|
| 1 | Implement bezier edge control points and mesh subdivision |
| 2 | Update warp shader to work with subdivided mesh |
| 3 | Implement surface grouping (group transform) |
| 4 | Implement blackout zone polygon drawing and rendering |

**Acceptance:**
- [ ] Bezier edges produce smooth curves on surface boundaries
- [ ] Mesh warp allows organic deformation
- [ ] Blackout zones mask projection correctly

---

### Phase F — Dual Display & Edge Blending (Tier 6)

**Goal:** Real dual-screen workflow and multi-projector support.

| # | Task |
|---|------|
| 1 | Implement secondary `Window` node for projector output |
| 2 | Display enumeration and assignment UI |
| 3 | Implement edge blend shader (gradient alpha mask) |
| 4 | Add per-surface edge blend controls in sidebar |
| 5 | Implement projector profiles (color correction post-process) |

**Acceptance:**
- [ ] Setup UI on laptop, live output on projector simultaneously
- [ ] Edge blending produces seamless overlap between two projectors
- [ ] Projector color profiles compensate for hardware differences

---

### Phase G — External Integration (Tier 7)

**Goal:** OSC and MIDI control.

| # | Task |
|---|------|
| 1 | Implement `OscServer` autoload (UDP listener, message parsing) |
| 2 | Build OSC mapping UI with learn mode |
| 3 | Implement `MidiManager` autoload (device enumeration, CC routing) |
| 4 | Build MIDI mapping UI with learn mode |
| 5 | Wire OSC/MIDI to surface properties and cue triggers |

**Acceptance:**
- [ ] TouchOSC can control surface opacity via OSC
- [ ] MIDI knob controls shader parameter in real time
- [ ] OSC message advances cue list

---

### Phase H — Content Management & Polish (Tier 8)

**Goal:** Asset library, packaging, recording, export.

| # | Task |
|---|------|
| 1 | Build asset library panel with thumbnail generation |
| 2 | Implement drag-and-drop from library to surfaces |
| 3 | Implement project packaging (zip export/import) |
| 4 | Implement output recording (viewport capture to video) |
| 5 | Implement layout export (SVG/PDF) |

**Acceptance:**
- [ ] Asset library shows all imported media with thumbnails
- [ ] Can export and import a project bundle on another machine
- [ ] Output recording produces a playable video file

---

## 15. Acceptance Criteria (v2 Creative Suite Complete)

The v2 is considered feature-complete when:

- [ ] Images and videos load onto surfaces and warp correctly
- [ ] Content fit modes, opacity, and transforms work per surface
- [ ] Undo/redo covers all operations
- [ ] Canvas zoom/pan is smooth and usable
- [ ] At least 4 generative shader effects are available
- [ ] Layer compositing with blend modes works
- [ ] Audio-reactive mode drives effects from microphone
- [ ] Cue list with transitions enables basic show sequencing
- [ ] BPM sync locks effects to beat
- [ ] Dual window mode works (setup on laptop, output on projector)
- [ ] Edge blending produces seamless multi-projector overlap
- [ ] OSC input controls surface properties
- [ ] MIDI input controls surface properties
- [ ] All v1 features remain fully functional
- [ ] App runs at 60 fps with 4 surfaces, 2 layers each, on target hardware

---

*End of v2 feature plan.*
