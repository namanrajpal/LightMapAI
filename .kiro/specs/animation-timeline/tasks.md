# Implementation Plan: Animation Timeline (Phase 1)

## Overview

Implement the core animation timeline system for the ProjectionMapping app. This adds a TimelineManager autoload with AnimationPlayer, SurfaceProxy nodes bridging animated properties to SurfaceManager, a TimelinePanel UI with transport controls and track rows, keyframe editing for value tracks, JSON serialization, keyboard shortcuts, and error handling. All animated changes flow through the existing `surface_updated` signal path so ProjectionSurface, OutputWindow, and Sidebar react without modification.

## Tasks

- [x] 1. Create SurfaceProxy node script
  - [x] 1.1 Create `scripts/surface_proxy.gd` extending Node
    - Expose exported properties with setters: opacity (float), color (Color), visible_prop (bool), z_index_prop (int), corner_tl (Vector2), corner_tr (Vector2), corner_br (Vector2), corner_bl (Vector2), fit_mode (String)
    - Each setter forwards to `SurfaceManager.update_surface_property()` or `SurfaceManager.update_corners()` for corner properties
    - Maintain a local `_corners: Array` cache of 4 Vector2 values; reconstruct PackedVector2Array on any corner change
    - Implement `sync_from_surface()` to read current values from SurfaceManager into proxy properties (used on creation and when animation stops)
    - Guard setters with `SurfaceManager.get_surface(surface_id).is_empty()` check to handle freed surfaces
    - _Requirements: 1.5, 1.7, 12.4_

  - [ ]* 1.2 Write property test for SurfaceProxy forwarding
    - **Property 2: Proxy property forwarding**
    - **Validates: Requirements 1.7**

- [x] 2. Create TimelineManager autoload — core structure and proxy lifecycle
  - [x] 2.1 Create `autoload/timeline_manager.gd` extending Node
    - In `_ready()`: create an AnimationPlayer child, create an AnimationLibrary and add it to the player, connect to SurfaceManager `surface_added` and `surface_removed` signals
    - Implement `_on_surface_added(id)`: instantiate a SurfaceProxy, set its `surface_id` and `name` to `SurfaceProxy_{id}`, add as child, call `sync_from_surface()`
    - Implement `_on_surface_removed(id)`: find and `queue_free()` the corresponding SurfaceProxy child
    - Implement `get_proxy(surface_id) -> Node` to return the proxy for a given surface
    - Define signals: `playback_state_changed`, `playhead_moved`, `animation_scene_changed`, `animation_list_changed`, `track_changed`
    - _Requirements: 1.2, 1.3, 1.4_

  - [ ]* 2.2 Write property test for proxy-surface count invariant
    - **Property 1: Proxy-surface count invariant**
    - **Validates: Requirements 1.3, 1.4**

- [x] 3. Register TimelineManager autoload in project.godot
  - Add `TimelineManager="*res://autoload/timeline_manager.gd"` to the `[autoload]` section in `project.godot`, after ShaderRegistry
  - _Requirements: 1.1_

- [x] 4. Checkpoint — Verify proxy lifecycle
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement animation scene CRUD on TimelineManager
  - [x] 5.1 Add animation scene management methods
    - Maintain `_scenes: Dictionary` mapping scene name to metadata (duration, loop_mode, armed_tracks)
    - Maintain `_active_scene_name: String`
    - Implement `create_scene(name, duration)`: create a new Animation resource, set its length, add to AnimationLibrary, store metadata, emit `animation_list_changed`
    - Implement `delete_scene(name)`: remove from AnimationLibrary and `_scenes`, if active scene deleted clear active, emit `animation_list_changed`
    - Implement `rename_scene(old_name, new_name)`: reject if new_name already exists, update AnimationLibrary key, update `_scenes` key, update `_active_scene_name` if needed, emit `animation_list_changed`
    - Implement `set_active_scene(name)`: assign to AnimationPlayer, emit `animation_scene_changed`
    - Implement `get_active_scene_name()`, `get_scene_names()` accessors
    - Implement `set_scene_duration(name, duration)`: update Animation resource length and metadata
    - Implement `set_scene_loop_mode(name, loop: bool)`: set Animation loop mode (Animation.LOOP_NONE or Animation.LOOP_LINEAR), update metadata
    - Implement `get_scene_loop_mode(name) -> bool`
    - _Requirements: 2.1, 2.2, 2.3, 2.5, 2.6, 2.7, 2.8_

  - [ ]* 5.2 Write property test for animation scene CRUD round-trip
    - **Property 3: Animation scene CRUD round-trip**
    - **Validates: Requirements 2.1, 2.2, 2.3**

  - [ ]* 5.3 Write property test for scene metadata set/get consistency
    - **Property 4: Scene metadata set/get consistency**
    - **Validates: Requirements 2.5, 2.6, 2.7, 2.8**

- [x] 6. Implement keyframe editing API on TimelineManager
  - [x] 6.1 Add keyframe CRUD methods
    - Implement easing string to Godot constants mapping: linear → TRANS_LINEAR, ease_in → TRANS_QUAD+EASE_IN, ease_out → TRANS_QUAD+EASE_OUT, ease_in_out → TRANS_QUAD+EASE_IN_OUT, cubic → TRANS_CUBIC+EASE_IN_OUT
    - Implement `add_keyframe(surface_id, property, time, value, easing)`: find or create track in active Animation resource using path `SurfaceProxy_{id}:{property}`, insert key with value and easing, clamp time to [0.0, duration], default easing to "linear", emit `track_changed`
    - Implement `remove_keyframe(surface_id, property, time)`: find track, remove key at time, emit `track_changed`
    - Implement `move_keyframe(surface_id, property, old_time, new_time)`: remove key at old_time, re-insert at new_time (clamped), preserving value and easing, emit `track_changed`
    - Implement `update_keyframe_value(surface_id, property, time, value)`: find key at time, update value, emit `track_changed`
    - Implement `update_keyframe_easing(surface_id, property, time, easing)`: validate easing is one of 5 valid types (fall back to linear if not), update transition type, emit `track_changed`
    - Implement `get_keyframes(surface_id, property) -> Array[Dictionary]`: return array of {time, value, easing} for all keys on the track
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 12.2, 12.5_

  - [ ]* 6.2 Write property test for keyframe add/remove round-trip
    - **Property 5: Keyframe add/remove round-trip**
    - **Validates: Requirements 3.1, 3.2**

  - [ ]* 6.3 Write property test for keyframe mutation preserves identity
    - **Property 6: Keyframe mutation preserves identity**
    - **Validates: Requirements 3.3, 3.4, 3.5, 3.6**

  - [ ]* 6.4 Write property test for keyframe time clamping
    - **Property 11: Keyframe time clamping**
    - **Validates: Requirements 12.5**

- [x] 7. Implement playback controls on TimelineManager
  - [x] 7.1 Add playback methods
    - Implement `play()`: if no active scene, no-op with warning; start AnimationPlayer, emit `playback_state_changed(true)`
    - Implement `pause()`: pause AnimationPlayer, emit `playback_state_changed(false)`
    - Implement `stop()`: stop AnimationPlayer, seek to 0.0, emit `playback_state_changed(false)` and `playhead_moved(0.0)`
    - Implement `seek(time)`: clamp to [0.0, duration], seek AnimationPlayer, emit `playhead_moved`
    - Implement `step_forward()`: seek to current_time + 1.0/60.0, clamped at duration
    - Implement `step_backward()`: seek to current_time - 1.0/60.0, clamped at 0.0
    - Implement `set_speed(multiplier)`: clamp to [0.1, 4.0], set AnimationPlayer speed_scale
    - Implement `get_speed()`, `is_playing()`, `get_playhead_time()`, `get_duration()` accessors
    - Connect AnimationPlayer `animation_finished` signal to handle one-shot stop (leave playhead at end)
    - In `_process()`: while playing, emit `playhead_moved` each frame with current position
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9_

  - [ ]* 7.2 Write property test for playback state machine
    - **Property 7: Playback state machine**
    - **Validates: Requirements 4.1, 4.2, 4.3, 7.1**

  - [ ]* 7.3 Write property test for seek and step clamping
    - **Property 8: Seek and step clamping**
    - **Validates: Requirements 4.4, 4.5, 4.6, 7.5, 7.6, 7.7, 7.8**

  - [ ]* 7.4 Write property test for speed multiplier clamping
    - **Property 9: Speed multiplier clamping**
    - **Validates: Requirements 4.7**

- [x] 8. Checkpoint — Verify core TimelineManager API
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement track armability on TimelineManager
  - [x] 9.1 Add arm/disarm methods and visibility logic
    - Store armed state per scene in `_scenes[name].armed_tracks` as `Dictionary` of `surface_id -> Array[String]`
    - Default armed properties for new surfaces: `["opacity", "visible_prop"]`
    - Implement `set_track_armed(surface_id, property, armed)`: update armed_tracks, emit `track_changed`
    - Implement `is_track_armed(surface_id, property) -> bool`
    - Implement `get_armed_tracks(surface_id) -> Array[String]`
    - Implement `get_visible_tracks(surface_id) -> Array[String]`: return tracks that are armed OR have keyframes in the active scene
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6_

  - [ ]* 9.2 Write property test for track visibility rules
    - **Property 12: Track visibility rules**
    - **Validates: Requirements 13.2, 13.3, 13.4, 13.5, 13.6**

- [x] 10. Implement JSON serialization on TimelineManager
  - [x] 10.1 Add serialize/deserialize methods
    - Implement `serialize_animations() -> Dictionary`: iterate all scenes, for each scene iterate all tracks in the Animation resource, serialize each keyframe as {time, value, easing} using the value serialization rules (float→number, Color→"#RRGGBB", Vector2→[x,y], bool→boolean, int→integer, String→string), include armed_tracks per scene, include active_scene name, wrap in version:1 envelope
    - Implement `deserialize_animations(data)`: validate data structure, skip gracefully on malformed JSON (log error, init empty), iterate scenes, for each track check surface_id exists in SurfaceManager (skip missing with warning per Req 12.1), for each keyframe validate easing (fall back to linear per Req 12.2), reconstruct Animation resources and metadata, set active scene
    - Handle missing `"animations"` key gracefully (init empty, no error per Req 9.6)
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 12.1, 12.2, 12.3_

  - [ ]* 10.2 Write property test for serialization round-trip
    - **Property 10: Serialization round-trip**
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 9.7**

  - [ ]* 10.3 Write property test for missing surface graceful skip
    - **Property 13: Missing surface graceful skip**
    - **Validates: Requirements 12.1**

  - [ ]* 10.4 Write property test for unknown easing fallback
    - **Property 14: Unknown easing fallback**
    - **Validates: Requirements 12.2**

  - [ ]* 10.5 Write property test for malformed JSON recovery
    - **Property 15: Malformed JSON recovery**
    - **Validates: Requirements 12.3**

- [x] 11. Hook serialization into SurfaceManager save/load
  - Modify `autoload/surface_manager.gd` `save_config()`: after building the data dictionary, call `TimelineManager.serialize_animations()` and add result under `data["animations"]`
  - Modify `autoload/surface_manager.gd` `load_config()`: after rebuilding surfaces, check for `data.get("animations", {})` and pass to `TimelineManager.deserialize_animations()`
  - _Requirements: 9.1, 9.5, 9.6_

- [x] 12. Checkpoint — Verify serialization round-trip
  - Ensure all tests pass, ask the user if questions arise.

- [x] 13. Create TimelinePanel UI
  - [x] 13.1 Create `scripts/timeline_panel.gd` extending VBoxContainer
    - Build the TransportBar (HBoxContainer) programmatically with: PlayPauseBtn, StopBtn, StepBackBtn, StepFwdBtn, TimeLabel ("00:00.00"), LoopToggle (toggle_mode Button), SpeedSelector (OptionButton with 0.1x to 4.0x in 0.1 increments, default 1.0x), SceneSelector (OptionButton for animation scene picker), NewSceneBtn, CollapseBtn
    - Build the TrackArea (ScrollContainer > VBoxContainer) for surface track rows
    - Set `custom_minimum_size.y = 200` and enforce minimum 100px
    - Connect TransportBar buttons to TimelineManager: PlayPauseBtn → toggle play/pause, StopBtn → stop, StepBackBtn → step_backward, StepFwdBtn → step_forward
    - Connect LoopToggle to `TimelineManager.set_scene_loop_mode()`
    - Connect SpeedSelector to `TimelineManager.set_speed()`
    - Connect SceneSelector to `TimelineManager.set_active_scene()`
    - Connect NewSceneBtn to show a dialog for creating a new scene (name + duration input)
    - Connect CollapseBtn to toggle panel between full height and transport-bar-only strip
    - Connect TimelineManager signals: `playback_state_changed` → update PlayPauseBtn text, `playhead_moved` → update TimeLabel and playhead position, `animation_scene_changed` → refresh tracks, `animation_list_changed` → refresh SceneSelector, `track_changed` → refresh affected track row
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.8, 5.11_

  - [x] 13.2 Implement surface track rows with expandable property sub-tracks
    - Listen to `SurfaceManager.surface_added` and `surface_removed` to add/remove track rows
    - Each surface row: TrackHeader (HBoxContainer with surface label, expand/collapse toggle) + KeyframeStrip (custom Control using `_draw()` for diamond shapes)
    - On click of surface row header, expand to show property sub-track rows for visible tracks (armed or has keyframes)
    - Each property sub-track row: PropertyLabel, ArmToggle (CheckButton), KeyframeStrip
    - ArmToggle connects to `TimelineManager.set_track_armed()`
    - Disarmed tracks with keyframes shown dimmed (modulate alpha)
    - _Requirements: 5.4, 5.5, 13.2, 13.3, 13.4, 13.5, 13.6_

  - [x] 13.3 Implement keyframe diamond rendering and playhead line
    - In each KeyframeStrip `_draw()`: query `TimelineManager.get_keyframes()` for the track, draw diamond shapes at time positions scaled to strip width
    - Draw a vertical playhead line spanning the full TrackArea height, positioned at current playback time
    - Implement playhead dragging: on mouse click/drag in the track area, calculate time from x position and call `TimelineManager.seek()`
    - Update playhead position each frame during playback via `playhead_moved` signal
    - _Requirements: 5.6, 5.7, 5.8_

  - [x] 13.4 Implement TimeLabel formatting
    - Format current time as `MM:SS.ff` (minutes, seconds, centiseconds) in the TransportBar TimeLabel
    - Update each frame during playback and on seek
    - _Requirements: 5.3_

- [x] 14. Wire TimelinePanel into App.tscn layout
  - Modify `scenes/app.tscn`: add a new node `TimelinePanel` of type `VBoxContainer` with script `res://scripts/timeline_panel.gd` as a child of `UILayer`, positioned between `MiddleArea` and `StatusBar`
  - Set `unique_name_in_owner = true` and `layout_mode = 2`
  - Set `custom_minimum_size = Vector2(0, 200)`
  - Update `load_steps` count in the tscn header to account for the new script resource
  - _Requirements: 5.1_

- [x] 15. Checkpoint — Verify TimelinePanel renders correctly
  - Ensure all tests pass, ask the user if questions arise.

- [x] 16. Add keyboard shortcuts in App.gd
  - [x] 16.1 Modify `scripts/app.gd` `_unhandled_key_input()` to add timeline shortcuts
    - Space bar: if TimelinePanel is visible, toggle play/pause via `TimelineManager.play()` / `TimelineManager.pause()` based on `TimelineManager.is_playing()`
    - Home key: `TimelineManager.seek(0.0)`
    - End key: `TimelineManager.seek(TimelineManager.get_duration())`
    - Left arrow key: `TimelineManager.step_backward()`
    - Right arrow key: `TimelineManager.step_forward()`
    - Ensure these shortcuts don't conflict with existing shortcuts (they don't — existing uses Ctrl+key, Delete, G, L, brackets, 1-4)
    - _Requirements: 7.1, 7.5, 7.6, 7.7, 7.8_

- [x] 17. Implement SurfaceManager integration guards
  - [x] 17.1 Ensure manual edits and animated playback coexist
    - While AnimationPlayer is stopped, SurfaceManager accepts manual edits normally (no changes needed — existing behavior)
    - When AnimationPlayer stops, call `sync_from_surface()` on all proxies to pick up any manual edits made during stop
    - Sidebar reflects animated values in real time via existing `surface_updated` signal (no changes needed)
    - OutputWindow reflects animated changes via existing signal flow (no changes needed)
    - When operator edits via Sidebar while stopped, TimelinePanel does not override (no changes needed — proxy setters only fire during animation playback)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.6, 8.7_

- [x] 18. Final checkpoint — Verify full integration
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- All code is GDScript targeting Godot 4.5
- Phase 2 items (BPM sync, queuing, zoom/snap, content method tracks, shader param animation, import/export, K/Shift+K shortcuts, rich keyframe editing UI) are excluded from this plan
