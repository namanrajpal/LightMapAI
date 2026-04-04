# Implementation Plan: Dual Window Output

## Overview

Implement a second output window for the ProjectionMapping app that renders surfaces fullscreen on a chosen display while the operator retains full control in the primary Setup Window. Tasks are ordered by dependency: foundation flags first, then the OutputWindow class, toolbar integration, keyboard shortcuts, persistence, and finally wiring everything together.

## Tasks

- [x] 1. Add output_only flag to ProjectionSurface and ProjectionCanvas
  - [x] 1.1 Add `output_only` flag to ProjectionSurface
    - Add `var output_only: bool = false` property to `scripts/projection_surface.gd`
    - Modify `initialize()` to accept an optional `p_output_only: bool = false` parameter
    - When `output_only` is true: skip `_create_corner_handles()`, skip connecting `_on_mode_changed`, return early from `_input()`, skip selection border and grid drawing in `_draw()`
    - Ensure content loading (shader, video, web, image) works identically regardless of `output_only`
    - _Requirements: 1.2, 3.5, 4.1, 4.2, 4.3_

  - [x] 1.2 Add `output_only` mode to ProjectionCanvas
    - Add `var output_only: bool = false` property to `scripts/projection_canvas.gd`
    - Add `initialize_output_mode()` method that sets `output_only = true`, connects SurfaceManager signals, and syncs all existing surfaces
    - Modify `_on_surface_added()` to pass `output_only` flag to `node.initialize(id, output_only)`
    - When `output_only` is true: skip input processing in `_input()`, skip surface selection handling
    - _Requirements: 1.2, 3.1, 3.2, 3.3, 3.4, 3.5_

  - [ ]* 1.3 Write property test for output-only structural invariant
    - **Property 2: Output-Only Structural Invariant**
    - Generate random surface sets, instantiate an output-only ProjectionCanvas, verify every surface node has `output_only == true`, zero corner handle children, and no selection/grid drawing
    - **Validates: Requirements 1.2, 3.5**

- [x] 2. Implement OutputWindow class
  - [x] 2.1 Create `scripts/output_window.gd`
    - Create new script extending `Window` with `class_name OutputWindow`
    - Add `signal output_window_closed()`
    - In `_ready()`: configure window as borderless, unresizable, 1920×1080; add black `ColorRect` background; instantiate `ProjectionCanvas` scene, call `initialize_output_mode()` on it
    - Implement `open_on_display(display_index: int)` — position window at `DisplayServer.screen_get_position(display_index)`, set size, show, make fullscreen
    - Connect `close_requested` signal to emit `output_window_closed` and `queue_free()`
    - Handle Escape key in `_unhandled_key_input()` to close the Output Window
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.2, 6.3_

  - [ ]* 2.2 Write property test for Output Window configuration
    - **Property 1: Output Window Configuration Invariant**
    - Generate random valid display indices, open the Output Window, assert borderless, unresizable, 1920×1080 viewport size
    - **Validates: Requirements 1.1**

  - [ ]* 2.3 Write property test for surface count synchronization
    - **Property 3: Surface Count Synchronization**
    - Generate random sequences of `add_surface()` / `remove_surface()` while Output Window is open, verify Output Canvas node count matches `SurfaceManager.surfaces.size()`
    - **Validates: Requirements 3.1, 3.2**

  - [ ]* 2.4 Write property test for surface property synchronization
    - **Property 4: Surface Property Synchronization**
    - Generate random property updates (corners, color, opacity, z_index, visibility, content_type, fit_mode), verify Output Canvas surfaces reflect updated values
    - **Validates: Requirements 3.3, 3.4, 4.4, 4.5**

  - [ ]* 2.5 Write property test for resource independence
    - **Property 5: Output Surface Resource Independence**
    - Generate surfaces with shader/video content, verify Output Canvas surfaces own distinct SubViewport instances from Setup Canvas surfaces
    - **Validates: Requirements 4.2, 4.3**

  - [ ]* 2.6 Write property test for cleanup on close
    - **Property 10: Cleanup on Close**
    - Generate random surface sets, close Output Window via various methods, verify `_output_window` is null and no orphaned Output Canvas nodes remain
    - **Validates: Requirements 1.3**

- [x] 3. Checkpoint — Verify foundation
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Add toolbar controls for dual output
  - [x] 4.1 Add DualOutputBtn and DisplaySelector nodes to `scenes/app.tscn`
    - Add a `VSeparator`, `Button` node named `DualOutputBtn` (unique, text "▶ Dual Output"), another `VSeparator`, and an `OptionButton` node named `DisplaySelector` (unique) to the Toolbar HBoxContainer, placed after the existing OutputBtn separator
    - _Requirements: 5.1, 5.3_

  - [x] 4.2 Implement toolbar logic in `scripts/toolbar.gd`
    - Add `@onready` references for `%DualOutputBtn` and `%DisplaySelector`
    - Implement `_populate_display_selector()` — enumerate displays via `DisplayServer.get_screen_count()`, add items with index and resolution, default to index 1 if multiple displays
    - Call `_populate_display_selector()` in `_ready()`
    - Connect `dual_output_btn.pressed` to `_on_dual_output_pressed()` which emits a signal or calls up to App
    - Add `set_dual_output_active(active: bool)` — toggles button label between "■ Stop Output" / "▶ Dual Output", sets `display_selector.disabled = active`
    - Add `get_selected_display() -> int` returning the selected display ID
    - Add `set_selected_display(index: int)` for restoring from config
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 2.1, 2.5_

  - [ ]* 4.3 Write property test for toolbar state consistency
    - **Property 6: Toolbar State Consistency**
    - Generate random sequences of open/close transitions, verify DualOutputBtn label and DisplaySelector disabled state match the Output Window's active state
    - **Validates: Requirements 5.2, 5.4**

  - [ ]* 4.4 Write property test for display targeting
    - **Property 11: Display Targeting**
    - For each connected display index, verify Display Selector contains an entry with resolution, and opening the Output Window positions it at `DisplayServer.screen_get_position(i)`
    - **Validates: Requirements 2.1, 2.2**

- [x] 5. Wire Output Window lifecycle in App.gd
  - [x] 5.1 Implement Output Window lifecycle in `scripts/app.gd`
    - Add `var _output_window: Window = null` and `@onready var toolbar: HBoxContainer = %Toolbar`
    - Implement `toggle_dual_output()` — if `_output_window` exists, close it; otherwise open it
    - Implement `_open_output_window()` — get display index from toolbar, create `OutputWindow`, add as child, call `open_on_display()`, connect `output_window_closed` signal, call `toolbar.set_dual_output_active(true)`
    - Implement `_close_output_window()` — `queue_free()` the window, null the reference, call `toolbar.set_dual_output_active(false)`
    - Implement `_on_output_window_closed()` — null the reference, update toolbar state (handles OS close / Escape close)
    - Connect toolbar's dual output action to `toggle_dual_output()`
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 5.1, 5.2_

  - [x] 5.2 Add Ctrl+D shortcut and F11/Tab guard in `scripts/app.gd`
    - In `_unhandled_key_input()`: add `KEY_D` with `ctrl_pressed` to call `toggle_dual_output()`
    - Guard F11/Tab: when `_output_window != null`, skip the `toggle_output_mode()` call and consume the event
    - Existing Escape behavior for single-window output mode remains unchanged
    - _Requirements: 6.1, 6.2, 7.1, 7.2_

  - [ ]* 5.3 Write property test for Ctrl+D toggle round-trip
    - **Property 7: Ctrl+D Toggle Round-Trip**
    - From random initial states (window open or closed), toggle twice, verify return to original state
    - **Validates: Requirements 6.1**

  - [ ]* 5.4 Write property test for single-window mode guard
    - **Property 8: Single-Window Mode Guard**
    - With Output Window open, attempt F11/Tab toggle, verify `SurfaceManager.is_output_mode` unchanged and UILayer remains visible
    - **Validates: Requirements 7.2**

- [x] 6. Checkpoint — Verify integration
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Add display preference persistence
  - [x] 7.1 Add `preferred_display_index` to SurfaceManager and config serialization
    - Add `var preferred_display_index: int = 1` to `autoload/surface_manager.gd`
    - Add `set_preferred_display(index: int)` and `get_preferred_display() -> int` methods
    - In `save_config()`: include `"preferred_display_index"` in the `"app"` section of the JSON
    - In `load_config()`: read `"preferred_display_index"` from the `"app"` section, fall back to 1 (or 0 if only one display) if the key is missing or the saved index exceeds `DisplayServer.get_screen_count()`
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 7.2 Wire persistence to toolbar DisplaySelector
    - When the operator changes the DisplaySelector selection, call `SurfaceManager.set_preferred_display()` with the new index
    - On app startup (in `_ready()` or after config load), restore the DisplaySelector to `SurfaceManager.preferred_display_index` via `toolbar.set_selected_display()`
    - _Requirements: 8.1, 8.2_

  - [ ]* 7.3 Write property test for display preference persistence round-trip
    - **Property 9: Display Preference Persistence Round-Trip**
    - Generate random valid display indices, set `preferred_display_index`, save config, load config, verify the value round-trips correctly
    - **Validates: Requirements 8.1, 8.2**

- [x] 8. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties from the design document
- The project uses GDScript (Godot 4.5) — all code examples and implementations use GDScript
- Checkpoints ensure incremental validation between major integration points
