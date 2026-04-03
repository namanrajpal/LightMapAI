# Projection Mapping MVP — User Guide

> **Version:** 1.0  
> **Engine:** Godot 4.x  
> **Target Display:** 1920×1080 @ 60 Hz (projector or monitor)

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Interface Overview](#2-interface-overview)
3. [Working with Surfaces](#3-working-with-surfaces)
4. [Warping & Corner Handles](#4-warping--corner-handles)
5. [Grid Overlay & Test Patterns](#5-grid-overlay--test-patterns)
6. [Z-Order & Layering](#6-z-order--layering)
7. [Save & Load](#7-save--load)
8. [Output Mode](#8-output-mode)
9. [Projector Setup Workflow](#9-projector-setup-workflow)
10. [Keyboard Shortcut Reference](#10-keyboard-shortcut-reference)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Getting Started

### First Launch

1. Open the project in **Godot 4.x** (4.6+ recommended)
2. Press **F5** or click the **Play** button
3. The app launches with one default surface (a blue quad with a grid overlay) centered on the canvas

The default configuration is loaded automatically from `data/default_config.json`. If the file is missing, a single surface is created at the center of the viewport.

### System Requirements

- macOS, Windows, or Linux
- Godot 4.6+ with GL Compatibility renderer
- A projector or secondary display for projection output (optional for testing)

---

## 2. Interface Overview

The app has two modes: **Setup Mode** (default) and **Output Mode**. In Setup Mode, you see the full UI:

```
┌──────────────────────────────────────────────────────────────┐
│ Toolbar: [+ Add] [Pattern ▾] [Grid ☐] [Save] [Load] [▶ Out]│
├──────────────┬───────────────────────────────────────────────┤
│   Sidebar    │                                               │
│   (250 px)   │         Projection Canvas                     │
│              │                                               │
│  Surface 1   │    ┌─────────────────────┐                    │
│  Surface 2   │    │   Surface (warped)  │                    │
│   ...        │    │    with grid overlay│                    │
│              │    └─────────────────────┘                    │
│  [+ Add]     │                                               │
├──────────────┴───────────────────────────────────────────────┤
│ Status: Surface 1  │ TL(460,240) TR(1460,240) ...  │ SETUP  │
└──────────────────────────────────────────────────────────────┘
```

### Toolbar (Top)

| Button | Function |
|--------|----------|
| **+ Add Surface** | Creates a new surface on the canvas |
| **Pattern** dropdown | Applies a test pattern to the selected surface (None, Checkerboard, Color Bars, Crosshair, White Flood) |
| **Grid** checkbox | Toggles the grid overlay on the selected surface |
| **Save** | Quick-saves the current configuration to disk |
| **Load** | Quick-loads the last saved configuration |
| **▶ Output Mode** | Switches to clean fullscreen output |

### Sidebar (Left, 250px)

Lists all surfaces as cards. Each card shows:
- **Label** — editable text field (click to rename, press Enter to confirm)
- **Color swatch** — click to open the color picker
- **Z-order** — current layer number
- **Grid button** — toggle grid for this surface
- **Lock button** (🔓/🔒) — lock to prevent accidental editing
- **Delete button** (🗑) — remove the surface

Click a card to **select** that surface.

### Canvas (Center)

The main working area where surfaces are displayed. Click directly on a surface to select it. The selected surface shows:
- Corner handles (draggable circles)
- A yellow selection border
- Corner labels (TL, TR, BR, BL) when hovering handles

### Status Bar (Bottom)

Displays:
- The name of the currently selected surface
- Real-time coordinates of all 4 corners: `TL(x,y) TR(x,y) BR(x,y) BL(x,y)`
- Current mode: `SETUP` or `OUTPUT`

---

## 3. Working with Surfaces

### Creating a Surface

- Click **+ Add Surface** in the toolbar or sidebar
- Or press **Ctrl+N**
- A new surface appears centered on the canvas with a unique color

### Selecting a Surface

- Click on a surface in the **canvas** area
- Or click its card in the **sidebar**
- The selected surface gets a yellow border and its corner handles appear

### Deleting a Surface

- Select the surface, then press **Delete**
- Or click the 🗑 button on its sidebar card

### Changing Label

- Click the text field on the surface's sidebar card
- Type a new name and press **Enter**

### Changing Color

- Click the color swatch on the surface's sidebar card
- Use the color picker to choose a new color
- The surface updates in real time

---

## 4. Warping & Corner Handles

Each surface has **4 corner handles** labeled TL (top-left), TR (top-right), BR (bottom-right), BL (bottom-left).

### Mouse Dragging (Coarse Adjustment)

1. Select a surface
2. Grab any corner handle (the circle becomes green when selected)
3. Drag to warp the surface into the desired shape

### Arrow Key Nudging (Pixel-Precise)

1. Select a surface
2. Click a corner handle to focus it (or press **1–4** to select TL/TR/BR/BL)
3. Use **arrow keys** to nudge by **1 pixel**
4. Hold **Shift + arrow keys** to nudge by **10 pixels**

### Selecting Corners by Number

When a surface is selected:
- Press **1** → select TL corner
- Press **2** → select TR corner
- Press **3** → select BR corner
- Press **4** → select BL corner

The selected corner handle turns green and receives keyboard focus for nudging.

### How Warping Works

The app uses **projective homography** (perspective transform) to distort each surface. When you move a corner, the app:
1. Computes a 3×3 homography matrix from the 4 corner positions
2. Inverts the matrix on the CPU
3. Passes it to the GPU shader, which warps every pixel in real time

This gives you true **keystone correction** — matching the surface to any convex quadrilateral shape on your physical wall.

---

## 5. Grid Overlay & Test Patterns

### Grid Overlay

The grid overlay draws evenly-spaced lines within the warped surface. It's invaluable for calibration — the lines should appear straight and evenly spaced on your projection surface.

**Toggle grid:**
- Press **G** (when a surface is selected)
- Or click the **Grid** checkbox in the toolbar
- Or click the **Grid** button on the surface's sidebar card

The grid follows the warp — if lines look bent on the physical surface, adjust the corners until they straighten out.

### Test Patterns

Select a test pattern from the **Pattern** dropdown in the toolbar:

| Pattern | Use Case |
|---------|----------|
| **None** | Shows the surface's solid color (default) |
| **Checkerboard** | Black & white checkerboard for geometry alignment |
| **Color Bars** | SMPTE-style color bars for color calibration |
| **Crosshair** | Center cross with quarter lines for centering |
| **White Flood** | Full white fill for brightness/focus testing |

Test patterns are generated procedurally (no external image files needed) and warp correctly with the surface.

---

## 6. Z-Order & Layering

Surfaces can overlap. The **z-order** determines which surface renders on top.

### Adjusting Z-Order

- Select a surface, then press **]** (right bracket) to move it **forward** (on top)
- Press **[** (left bracket) to move it **backward** (behind)
- The z-order number is displayed on each sidebar card as `Z:0`, `Z:1`, etc.

Higher z-values render on top of lower ones.

---

## 7. Save & Load

### Quick Save

- Press **Ctrl+S** or click the **Save** button
- On first save, the config is written to `user://configs/config.json`
- Subsequent saves overwrite the same file

### Quick Load

- Press **Ctrl+O** or click the **Load** button
- Restores all surfaces from the last saved configuration

### Default Configuration

On first launch, the app loads `data/default_config.json` which ships with one centered surface. You can edit this file to change the default starting state.

### Config File Location

Godot's `user://` path maps to:

| OS | Path |
|----|------|
| **macOS** | `~/Library/Application Support/Godot/app_userdata/ProjectionMapping/configs/` |
| **Windows** | `%APPDATA%\Godot\app_userdata\ProjectionMapping\configs\` |
| **Linux** | `~/.local/share/godot/app_userdata/ProjectionMapping/configs/` |

### Config File Format

Configurations are saved as human-readable JSON:

```json
{
  "version": 1,
  "app": { "canvas_size": [1920, 1080] },
  "surfaces": [
    {
      "id": "a1b2c3d4",
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

You can hand-edit this file if needed, or share it between machines.

---

## 8. Output Mode

Output Mode hides all UI chrome and shows **only the warped surfaces** — this is what you project onto your physical surfaces.

### Entering Output Mode

- Press **F11** or **Tab**
- Or click the **▶ Output Mode** button in the toolbar
- The window goes fullscreen and all UI (toolbar, sidebar, status bar, corner handles, grid overlays) disappears

### Exiting Output Mode

- Press **Esc**, **F11**, or **Tab**
- The window returns to windowed mode and all UI reappears

### What's Hidden in Output Mode

| Element | Visible in Setup | Visible in Output |
|---------|:---:|:---:|
| Toolbar | ✅ | ❌ |
| Sidebar | ✅ | ❌ |
| Status Bar | ✅ | ❌ |
| Corner Handles | ✅ (selected only) | ❌ |
| Grid Overlay | ✅ (if enabled) | ❌ |
| Surface Content | ✅ | ✅ |
| Selection Border | ✅ (selected only) | ❌ |

---

## 9. Projector Setup Workflow

### Step-by-Step

1. **Connect your projector** (e.g., Nomvdic PJ) via HDMI
2. **Arrange displays** — macOS: System Settings → Displays → Arrange side by side
3. **Launch the app** in Godot (F5)
4. **Create surfaces** for each physical projection area (+ Add Surface)
5. **Drag the Godot window** to the projector display
6. **Enter Output Mode** (F11)
7. **Adjust corners** — switch back to Setup Mode (Esc), warp corners to match physical geometry, switch back to Output Mode to verify
8. **Use test patterns** — apply Checkerboard or Crosshair to verify alignment
9. **Toggle grid** — ensure grid lines appear straight on the physical surface
10. **Save your configuration** (Ctrl+S) once you're happy with the calibration
11. **Enter Output Mode** for the final presentation

### Tips

- Use **arrow key nudging** (1px steps) for final fine-tuning
- The **Crosshair** test pattern is great for centering
- The **Checkerboard** reveals geometric distortion most clearly
- Save frequently — press **Ctrl+S** after each good calibration step
- For multi-surface setups, work on one surface at a time

### Dual-Display Workflow

Currently, the app runs in a single window. The recommended workflow is:

1. Set up your surfaces in Setup Mode on your laptop screen
2. Drag the window to the projector
3. Enter Output Mode for projection
4. Press Esc to return to Setup Mode for adjustments

> **Future Enhancement:** A dual-window mode where the setup UI stays on the laptop while a second window outputs to the projector.

---

## 10. Keyboard Shortcut Reference

### Global Shortcuts

| Key | Action |
|-----|--------|
| **F11** or **Tab** | Toggle Setup ↔ Output Mode |
| **Esc** | Return to Setup Mode (from Output) |
| **Ctrl+S** | Quick Save configuration |
| **Ctrl+O** | Quick Load configuration |
| **Ctrl+N** | Add new surface |

### Surface Shortcuts (when a surface is selected)

| Key | Action |
|-----|--------|
| **Delete** | Delete selected surface |
| **G** | Toggle grid overlay |
| **L** | Toggle lock |
| **]** | Move surface forward (z-order) |
| **[** | Move surface backward (z-order) |
| **1** | Select TL corner |
| **2** | Select TR corner |
| **3** | Select BR corner |
| **4** | Select BL corner |

### Corner Shortcuts (when a corner handle is focused)

| Key | Action |
|-----|--------|
| **Arrow Keys** | Nudge corner 1 pixel |
| **Shift+Arrow Keys** | Nudge corner 10 pixels |

---

## 11. Troubleshooting

### App won't start / "SurfaceManager not declared"

The `SurfaceManager` autoload may not be registered. Check `project.godot`:
```
[autoload]
SurfaceManager="*res://autoload/surface_manager.gd"
```
If you edited `project.godot` while Godot was open, **close and reopen** the editor.

### Surface appears as a thin line or doesn't render

The corners may be too close together or in a degenerate (self-intersecting) arrangement. Try resetting the surface:
1. Delete the surface
2. Create a new one (it spawns as a normal rectangle)

### Grid lines appear curved

This is expected for extreme warps. The grid lines are straight in UV space but curve when projected through a strong perspective warp. If the lines look curved on your *physical* projection surface, that means the corners need adjustment.

### Save/Load not working

Check that the `user://configs/` directory is writable. On first save, the app creates this directory automatically. If you see errors in the Output panel, check file permissions.

### Performance issues with many surfaces

Each surface runs its own shader. With 10+ surfaces, you may notice frame drops. Optimization tips:
- Hide surfaces you're not actively calibrating (set `visible: false`)
- Disable grid overlays on surfaces you're not adjusting
- Use solid colors instead of test patterns when not calibrating

---

*End of User Guide*
