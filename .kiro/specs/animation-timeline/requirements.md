# Requirements Document

## Introduction

The Animation Timeline feature adds a Godot-native keyframe-based timeline editor to the ProjectionMapping application. It enables operators to animate surface properties over time for live projection mapping shows. The system uses Godot's built-in AnimationPlayer and Animation resources as the core runtime, with a proxy node pattern to bridge AnimationPlayer tracks to SurfaceManager surface data. A custom timeline UI panel provides playback controls, keyframe editing, and scrubbing. Animation data is serialized as JSON alongside existing config data for portability.

## Glossary

- **TimelineManager**: An autoload singleton that hosts an AnimationPlayer node and manages proxy nodes, animation lifecycle, and playback orchestration.
- **AnimationPlayer**: Godot's built-in node that plays Animation resources, interpolating property values over time along tracks.
- **ProxyNode**: A Node instance (one per surface) with exported properties that AnimationPlayer value tracks can target. Property changes on a ProxyNode are forwarded to SurfaceManager.
- **Armed_Track**: A property track that the operator has explicitly enabled for keyframing and display in the Timeline_Panel. Only armed or previously-keyed tracks are shown by default.
- **SurfaceManager**: The existing autoload singleton that stores all surface data as Array[Dictionary] and emits surface_updated signals on property changes.
- **ProjectionSurface**: The existing Control node that renders a single warpable surface quad and responds to surface_updated signals.
- **ShaderRegistry**: The existing autoload singleton that discovers, catalogs, and provides shader effects with typed parameters.
- **Timeline_Panel**: A Godot Control-based bottom dock UI that displays track rows, keyframes, a playhead, and playback controls.
- **Keyframe**: A data point on a track specifying a property value at a specific time, with an associated easing type.
- **Track**: A sequence of keyframes for a single animatable property on a single surface.
- **Playhead**: A visual indicator on the Timeline_Panel representing the current playback position in seconds.
- **Animation_Scene**: A named animation containing a duration, loop mode, and a set of tracks with keyframes. Multiple Animation_Scenes can be created and queued.
- **Transport_Bar**: The toolbar area within the Timeline_Panel containing play/pause/stop buttons, time display, loop toggle, speed control, and BPM input.
- **Easing_Type**: The interpolation curve applied between two keyframes (linear, ease_in, ease_out, ease_in_out, cubic).
- **BPM_Sync**: An optional mode that aligns the timeline grid and snap points to beats per minute for music-driven shows.
- **Output_Window**: The existing secondary Window node that renders projection surfaces fullscreen on a chosen display.

## Requirements

### Requirement 1: TimelineManager Autoload and Proxy Node Architecture

**User Story:** As a projection mapping operator, I want a centralized timeline management system, so that AnimationPlayer can drive surface properties through a well-defined proxy node pattern.

#### Acceptance Criteria

1. THE TimelineManager SHALL be registered as an autoload singleton in project.godot.
2. THE TimelineManager SHALL host exactly one AnimationPlayer child node for animation playback.
3. WHEN a surface is added to SurfaceManager, THE TimelineManager SHALL create a corresponding ProxyNode as a child of TimelineManager.
4. WHEN a surface is removed from SurfaceManager, THE TimelineManager SHALL remove and free the corresponding ProxyNode.
5. THE ProxyNode SHALL expose the following exported properties: opacity (float), color (Color), visible (bool), z_index (int), corner_tl (Vector2), corner_tr (Vector2), corner_br (Vector2), corner_bl (Vector2), and fit_mode (String).
6. THE ProxyNode SHALL maintain a dynamic animatable-parameter registry for shader parameters. WHEN the active shader effect changes on a surface, THE ProxyNode SHALL update its parameter registry to match the new effect's parameter definitions from ShaderRegistry. Tracks referencing parameters from a previous shader effect SHALL be preserved in animation data but marked inactive during playback.
7. WHEN a ProxyNode property value changes during animation playback, THE ProxyNode SHALL call SurfaceManager.update_surface_property() with the corresponding surface id, property key, and new value. FOR corner properties (corner_tl, corner_tr, corner_br, corner_bl), THE ProxyNode SHALL reconstruct the PackedVector2Array and call SurfaceManager.update_corners().
8. WHEN a ProxyNode shader parameter property changes during animation playback, THE ProxyNode SHALL locate the corresponding ProjectionSurface node and call set_shader_param() with the parameter name and new value. IF the parameter does not exist on the current ShaderMaterial, THE ProxyNode SHALL ignore the change and log a warning.

### Requirement 2: Animation Resource Management

**User Story:** As a projection mapping operator, I want to create, edit, and manage multiple named animations, so that I can prepare different scenes and cues for a live show.

#### Acceptance Criteria

1. THE TimelineManager SHALL support creating a new Animation_Scene with a user-specified name and duration in seconds.
2. THE TimelineManager SHALL support deleting an existing Animation_Scene by name.
3. THE TimelineManager SHALL support renaming an existing Animation_Scene.
4. THE TimelineManager SHALL support duplicating an existing Animation_Scene into a new Animation_Scene with a different name.
5. THE TimelineManager SHALL maintain a list of all Animation_Scenes and provide access to the currently active Animation_Scene.
6. WHEN the operator selects a different Animation_Scene, THE TimelineManager SHALL load that Animation_Scene into the AnimationPlayer and update the Timeline_Panel display.
7. THE TimelineManager SHALL support setting the loop mode of an Animation_Scene to one of: none (one-shot) or loop.
8. THE TimelineManager SHALL support adjusting the duration of an existing Animation_Scene.

### Requirement 3: Keyframe Editing

**User Story:** As a projection mapping operator, I want to add, remove, and modify keyframes on property tracks, so that I can define how surface properties change over time.

#### Acceptance Criteria

1. WHEN the operator adds a keyframe at a specific time on a property track, THE TimelineManager SHALL insert a Keyframe with the current property value and a default Easing_Type of linear.
2. WHEN the operator removes a keyframe, THE TimelineManager SHALL delete the Keyframe from the track and update the Animation resource.
3. WHEN the operator moves a keyframe to a different time position, THE TimelineManager SHALL update the Keyframe time in the Animation resource.
4. WHEN the operator changes the value of a keyframe, THE TimelineManager SHALL update the stored value in the Animation resource.
5. WHEN the operator changes the Easing_Type of a keyframe, THE TimelineManager SHALL update the interpolation transition for that key in the Animation resource.
6. THE TimelineManager SHALL support the following Easing_Types per keyframe: linear, ease_in, ease_out, ease_in_out, and cubic.
7. WHEN the operator adds a keyframe for content_type or content_source, THE TimelineManager SHALL use a method call track to trigger the content change at the specified time rather than a value interpolation track.
8. WHEN the operator seeks or scrubs the Playhead to a new position, THE TimelineManager SHALL restore the most recent content-change method call event at or before the Playhead position, ensuring content state is correct after non-linear seeking.

### Requirement 4: Playback Controls

**User Story:** As a projection mapping operator, I want full playback control over animations, so that I can preview, perform, and fine-tune animated sequences during a live show.

#### Acceptance Criteria

1. WHEN the operator presses the play button or the Space bar, THE TimelineManager SHALL start or resume playback of the active Animation_Scene from the current Playhead position.
2. WHEN the operator presses the pause button or the Space bar during playback, THE TimelineManager SHALL pause playback at the current Playhead position.
3. WHEN the operator presses the stop button, THE TimelineManager SHALL stop playback and reset the Playhead to time 0.0.
4. WHEN the operator drags the Playhead to a new position, THE TimelineManager SHALL seek the AnimationPlayer to that time and update all animated properties to their values at that time.
5. WHEN the operator presses the step-forward control, THE TimelineManager SHALL advance the Playhead by one frame (1.0 / 60.0 seconds).
6. WHEN the operator presses the step-backward control, THE TimelineManager SHALL move the Playhead back by one frame (1.0 / 60.0 seconds), clamping at 0.0.
7. THE TimelineManager SHALL support a playback speed multiplier adjustable from 0.1x to 4.0x in 0.1 increments, with a default of 1.0x.
8. WHILE the AnimationPlayer is playing, THE Timeline_Panel SHALL update the Playhead position and current time display each frame to reflect the actual playback position.
9. WHEN playback reaches the end of the Animation_Scene and loop mode is set to none, THE TimelineManager SHALL stop playback and leave the Playhead at the end position.

### Requirement 5: Timeline Panel UI Layout

**User Story:** As a projection mapping operator, I want a visual timeline panel in the application, so that I can see and interact with animation tracks and keyframes.

#### Acceptance Criteria

1. THE Timeline_Panel SHALL be a Godot Control node positioned between the MiddleArea and StatusBar in the UILayer VBoxContainer.
2. THE Timeline_Panel SHALL have a configurable height with a default of 200 pixels and a minimum of 100 pixels.
3. THE Timeline_Panel SHALL display a Transport_Bar at the top containing: play/pause button, stop button, step-backward button, step-forward button, current time label (in seconds with two decimal places), loop mode toggle, playback speed selector, and BPM input field.
4. THE Timeline_Panel SHALL display a scrollable track area below the Transport_Bar, with one row per surface.
5. WHEN the operator clicks on a surface row header, THE Timeline_Panel SHALL expand the row to reveal individual property sub-tracks for that surface.
6. THE Timeline_Panel SHALL display Keyframe indicators as diamond shapes at their corresponding time positions on each track.
7. THE Timeline_Panel SHALL display a vertical Playhead line spanning the full height of the track area at the current playback time.
8. WHEN the operator drags the Playhead, THE Timeline_Panel SHALL update the Playhead position in real time and seek the AnimationPlayer to the corresponding time.
9. THE Timeline_Panel SHALL support horizontal zoom in and zoom out on the time axis, adjustable via mouse scroll wheel with Ctrl held or via dedicated zoom buttons.
10. THE Timeline_Panel SHALL support a configurable snap-to-grid resolution (e.g., 0.1s, 0.25s, 0.5s, 1.0s) that constrains keyframe placement to grid intervals.
11. THE Timeline_Panel SHALL be hideable via a toggle button, collapsing to a minimal Transport_Bar-only strip.

### Requirement 6: Keyframe Interaction in Timeline UI

**User Story:** As a projection mapping operator, I want to visually add, move, and edit keyframes on the timeline, so that I can intuitively build animations.

#### Acceptance Criteria

1. WHEN the operator double-clicks on an empty area of a property track, THE Timeline_Panel SHALL add a new Keyframe at that time position with the current property value.
2. WHEN the operator clicks and drags an existing Keyframe diamond, THE Timeline_Panel SHALL move the Keyframe to the new time position, snapping to the grid if snap is enabled.
3. WHEN the operator right-clicks on a Keyframe diamond, THE Timeline_Panel SHALL display a context menu with options: Edit Value, Change Easing, and Delete Keyframe.
4. WHEN the operator selects Edit Value from the context menu, THE Timeline_Panel SHALL display an inline editor appropriate to the property type (slider for float, color picker for Color, checkbox for bool, spinbox for int).
5. WHEN the operator selects Change Easing from the context menu, THE Timeline_Panel SHALL display a submenu listing all supported Easing_Types and apply the selected easing to the Keyframe.
6. WHEN the operator selects Delete Keyframe from the context menu, THE Timeline_Panel SHALL remove the Keyframe from the track.

### Requirement 7: Keyboard Shortcuts

**User Story:** As a projection mapping operator, I want keyboard shortcuts for common timeline operations, so that I can work efficiently during show preparation and performance.

#### Acceptance Criteria

1. WHEN the operator presses the Space bar and the Timeline_Panel is visible, THE TimelineManager SHALL toggle between play and pause states.
2. WHEN the operator presses the K key while a property sub-track is selected in the Timeline_Panel, THE TimelineManager SHALL add a keyframe at the current Playhead position for that specific property using its current value.
3. WHEN the operator presses Shift+K while a surface track is selected, THE TimelineManager SHALL add a keyframe at the current Playhead position for all armed properties of the selected surface using their current values.
4. WHEN the operator presses the Delete key while a Keyframe is selected in the Timeline_Panel, THE TimelineManager SHALL remove the selected Keyframe.
5. WHEN the operator presses the Left arrow key, THE TimelineManager SHALL step the Playhead backward by one grid unit.
6. WHEN the operator presses the Right arrow key, THE TimelineManager SHALL step the Playhead forward by one grid unit.
7. WHEN the operator presses the Home key, THE TimelineManager SHALL move the Playhead to time 0.0.
8. WHEN the operator presses the End key, THE TimelineManager SHALL move the Playhead to the end of the active Animation_Scene duration.

### Requirement 8: Integration with SurfaceManager and Existing Systems

**User Story:** As a projection mapping operator, I want the timeline to integrate seamlessly with the existing surface editing workflow, so that manual edits and animated playback coexist without conflict.

#### Acceptance Criteria

1. WHILE the AnimationPlayer is stopped, THE SurfaceManager SHALL accept manual property edits from the Sidebar and canvas interactions as the current behavior.
2. WHILE the AnimationPlayer is playing, THE TimelineManager SHALL drive surface properties through ProxyNode updates, and THE Sidebar controls SHALL reflect the animated values in real time.
3. WHEN the AnimationPlayer transitions from playing to stopped, THE TimelineManager SHALL leave surface properties at their last animated values until the operator manually edits them.
4. WHEN a surface property is updated by the AnimationPlayer through a ProxyNode, THE ProjectionSurface SHALL apply the change through the existing _on_surface_updated handler via the surface_updated signal.
5. WHEN a shader parameter is animated through a ProxyNode, THE ProjectionSurface SHALL apply the change through the existing set_shader_param method, following the same code path as Sidebar slider changes.
6. WHILE the AnimationPlayer is playing, THE Output_Window SHALL reflect all animated property changes in real time through the existing surface_updated signal flow.
7. WHEN the operator edits a surface property via the Sidebar while the AnimationPlayer is stopped, THE Timeline_Panel SHALL not modify or override that manual edit.

### Requirement 9: Animation Serialization

**User Story:** As a projection mapping operator, I want animation data saved and loaded alongside my surface configuration, so that I can persist and share my animated shows.

#### Acceptance Criteria

1. WHEN the operator saves the configuration via SurfaceManager.save_config(), THE TimelineManager SHALL serialize all Animation_Scenes into the config JSON under an "animations" key.
2. THE TimelineManager SHALL serialize each Animation_Scene as a JSON object containing: name (String), duration (float), loop_mode (String), and tracks (Array of track objects).
3. THE TimelineManager SHALL serialize each track as a JSON object containing: surface_id (String), property (String), track_type (String: "value" or "method"), and keys (Array of keyframe objects).
4. THE TimelineManager SHALL serialize each keyframe as a JSON object containing: time (float), value (Variant serialized to JSON-compatible type), and easing (String).
5. WHEN the operator loads a configuration via SurfaceManager.load_config(), THE TimelineManager SHALL deserialize the "animations" key and reconstruct all Animation_Scenes with their tracks and keyframes.
6. IF the config JSON does not contain an "animations" key, THEN THE TimelineManager SHALL initialize with an empty animation list and continue loading without error.
7. FOR ALL valid Animation_Scene data, serializing then deserializing SHALL produce an equivalent set of Animation_Scenes with identical track and keyframe data (round-trip property).
8. THE TimelineManager SHALL support exporting a single Animation_Scene to a standalone JSON file.
9. THE TimelineManager SHALL support importing an Animation_Scene from a standalone JSON file, adding the Animation_Scene to the current list.
10. WHEN importing an Animation_Scene that references surface IDs not present in the current configuration, THE TimelineManager SHALL skip tracks for missing surfaces and log a warning.

### Requirement 10: BPM Synchronization

**User Story:** As a projection mapping operator running music-driven shows, I want to synchronize the timeline grid to a BPM value, so that I can align keyframes to musical beats.

#### Acceptance Criteria

1. WHERE BPM_Sync is enabled, THE Timeline_Panel SHALL calculate the grid interval as 60.0 / BPM seconds per beat.
2. WHERE BPM_Sync is enabled, THE Timeline_Panel SHALL display beat markers on the time axis at each beat interval.
3. WHERE BPM_Sync is enabled and snap-to-grid is active, THE Timeline_Panel SHALL snap keyframe positions to the nearest beat subdivision.
4. THE Transport_Bar SHALL provide a BPM input field accepting values from 20 to 300, with a default of 120.
5. WHEN the operator changes the BPM value, THE Timeline_Panel SHALL recalculate and redraw the grid immediately.

### Requirement 11: Animation Scene Queuing

**User Story:** As a projection mapping operator, I want to queue multiple animations for sequential playback, so that I can build a full show setlist.

#### Acceptance Criteria

1. THE TimelineManager SHALL maintain an ordered queue of Animation_Scene names for sequential playback.
2. WHEN the operator adds an Animation_Scene to the queue, THE TimelineManager SHALL append the Animation_Scene name to the end of the queue.
3. WHEN the current Animation_Scene finishes playback (in non-looping mode) and the queue is not empty, THE TimelineManager SHALL automatically load and play the next Animation_Scene in the queue.
4. THE TimelineManager SHALL provide a method to clear the queue.
5. THE TimelineManager SHALL provide a method to remove a specific Animation_Scene from the queue by index.
6. THE Timeline_Panel SHALL display the current queue as an ordered list, allowing reordering via drag-and-drop.

### Requirement 12: Error Handling

**User Story:** As a projection mapping operator, I want the timeline system to handle errors gracefully, so that a corrupted animation or missing data does not crash the application.

#### Acceptance Criteria

1. IF an Animation_Scene contains a track referencing a surface ID that no longer exists, THEN THE TimelineManager SHALL skip that track during playback and log a warning message.
2. IF an Animation_Scene contains a keyframe with an unrecognized Easing_Type, THEN THE TimelineManager SHALL fall back to linear easing for that keyframe and log a warning message.
3. IF the animation JSON data fails to parse during load_config, THEN THE TimelineManager SHALL discard the animation data, initialize with an empty animation list, and log an error message.
4. IF a ProxyNode receives a property change for a shader parameter that does not exist on the current ShaderMaterial, THEN THE ProxyNode SHALL ignore the change and log a warning message.
5. IF the operator attempts to add a keyframe at a time beyond the Animation_Scene duration, THEN THE TimelineManager SHALL clamp the keyframe time to the Animation_Scene duration.

### Requirement 13: Track Discovery and Armability

**User Story:** As a projection mapping operator, I want to control which property tracks are visible and keyframeable in the timeline, so that the UI stays clean and I only see what I'm actively animating.

#### Acceptance Criteria

1. EACH surface SHALL expose a defined set of animatable properties: opacity, color, visible, z_index, corner_tl, corner_tr, corner_br, corner_bl, fit_mode, and any shader parameters from the active effect.
2. THE operator SHALL be able to arm or disarm individual property tracks per surface via a toggle in the Timeline_Panel track header.
3. THE Timeline_Panel SHALL only display armed tracks or tracks that already contain keyframes in the active Animation_Scene by default.
4. WHEN the operator arms a property track, THE Timeline_Panel SHALL immediately show that track row for the surface.
5. WHEN the operator disarms a property track that has no keyframes, THE Timeline_Panel SHALL hide that track row.
6. WHEN the operator disarms a property track that has existing keyframes, THE Timeline_Panel SHALL keep the track visible but visually indicate it is disarmed (e.g., dimmed). Existing keyframes SHALL be preserved.

## Phase Annotations

The following requirements are categorized by implementation phase:

**Phase 1 (Core — must-have for first implementation):**
- Requirement 1: TimelineManager Autoload and Proxy Node Architecture
- Requirement 2: Animation Resource Management (except AC 4 — duplicate)
- Requirement 3: Keyframe Editing (AC 1-6 only; AC 7-8 content method tracks are Phase 2)
- Requirement 4: Playback Controls
- Requirement 5: Timeline Panel UI Layout (AC 1-8, 11; AC 9-10 zoom/snap are Phase 2)
- Requirement 7: Keyboard Shortcuts (AC 1, 4-8; AC 2-3 keyframe shortcuts are Phase 2)
- Requirement 8: Integration with SurfaceManager and Existing Systems (AC 1-4, 6-7)
- Requirement 9: Animation Serialization (AC 1-7 only)
- Requirement 12: Error Handling
- Requirement 13: Track Discovery and Armability

**Phase 2 (Enhanced — after core is working):**
- Requirement 2 AC 4: Animation_Scene duplication
- Requirement 3 AC 7-8: Content change method tracks with scrub restore
- Requirement 5 AC 9-10: Zoom and snap-to-grid
- Requirement 6: Keyframe Interaction in Timeline UI (full context menus, inline editors)
- Requirement 7 AC 2-3: K/Shift+K keyframe shortcuts, Delete keyframe shortcut
- Requirement 8 AC 5: Shader parameter animation through proxy
- Requirement 9 AC 8-10: Import/export standalone animation files
- Requirement 10: BPM Synchronization
- Requirement 11: Animation Scene Queuing
