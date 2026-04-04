# Requirements Document

## Introduction

The Dual Window Output feature enables a two-display workflow for the ProjectionMapping application. The Setup Window remains on the operator's laptop with the full control UI (sidebar, toolbar, status bar, canvas preview), while a second Output Window opens on a connected projector display showing only the warped surfaces fullscreen. All surface edits in the Setup Window reflect live on the Output Window. This replaces the current single-window Output Mode toggle for multi-display setups, while preserving the existing single-display fallback.

## Glossary

- **Setup_Window**: The main application window (Godot's primary window) that displays the full control UI including toolbar, sidebar, status bar, and a canvas preview of all projection surfaces.
- **Output_Window**: A secondary Godot Window node that renders only the warped projection surfaces fullscreen on a selected display, with no UI chrome.
- **Output_Canvas**: A ProjectionCanvas instance inside the Output_Window that mirrors the surface data from SurfaceManager and renders output-only surface instances.
- **Display_Selector**: A UI dropdown in the toolbar that lists all connected displays and allows the operator to choose which display the Output_Window opens on.
- **SurfaceManager**: The autoload singleton that holds all surface data, emits CRUD and mode signals, and serves as the single source of truth for both windows.
- **Projection_Surface**: A Control node that renders one warpable quad (Polygon2D), including shader/video/web content via SubViewports and corner handles for calibration.
- **Output_Mode**: The existing single-window mode that hides UI chrome and goes fullscreen; retained as a fallback for single-display setups.
- **Live_Sync**: The mechanism by which surface property changes (corners, color, content, opacity, z-order, visibility) propagate from SurfaceManager to the Output_Canvas in real time.

## Requirements

### Requirement 1: Output Window Lifecycle

**User Story:** As a projection operator, I want to open and close a dedicated output window, so that I can project surfaces on a second display while keeping the control UI on my laptop.

#### Acceptance Criteria

1. WHEN the operator activates the dual-output action, THE Output_Window SHALL open as a new borderless, unresizable Godot Window node at 1920×1080 resolution.
2. WHEN the Output_Window opens, THE Output_Window SHALL display only the warped projection surfaces on a black background with no toolbar, sidebar, status bar, or corner handles.
3. WHEN the operator closes the Output_Window via the toolbar close action or keyboard shortcut, THE Output_Window SHALL be freed and all Output_Canvas surface instances SHALL be cleaned up.
4. IF the Output_Window is closed externally (via OS window close), THEN THE Setup_Window SHALL detect the closure and update the toolbar state to reflect that dual output is inactive.
5. WHILE the Output_Window is open, THE Setup_Window SHALL remain fully interactive with all UI controls operational.

### Requirement 2: Display Selection

**User Story:** As a projection operator, I want to choose which connected display the output window appears on, so that I can target the projector regardless of my display arrangement.

#### Acceptance Criteria

1. THE Display_Selector SHALL enumerate all connected displays using DisplayServer.get_screen_count and display each with its index and resolution.
2. WHEN the operator selects a display from the Display_Selector, THE Output_Window SHALL open on the selected display by positioning the window at that display's origin coordinates.
3. WHEN a display is connected or disconnected, THE Display_Selector SHALL refresh the list of available displays.
4. IF only one display is detected, THEN THE Display_Selector SHALL show a single entry and the operator SHALL still be able to open the Output_Window on that display.
5. THE Display_Selector SHALL default to the secondary display (index 1) when more than one display is connected.

### Requirement 3: Live Surface Synchronization

**User Story:** As a projection operator, I want all surface changes I make in the setup window to appear instantly on the output window, so that I can calibrate and adjust while seeing the live result on the projector.

#### Acceptance Criteria

1. WHEN a surface is added via SurfaceManager, THE Output_Canvas SHALL instantiate a corresponding output-only Projection_Surface for that surface.
2. WHEN a surface is removed via SurfaceManager, THE Output_Canvas SHALL remove and free the corresponding output-only Projection_Surface.
3. WHEN surface corners are updated in SurfaceManager, THE Output_Canvas Projection_Surface SHALL update its polygon vertices to match the new corner positions.
4. WHEN surface properties (color, opacity, z_index, visibility, content_type, content_source, fit_mode, shader_params) change in SurfaceManager, THE Output_Canvas Projection_Surface SHALL apply the updated property values.
5. WHILE the Output_Window is open, THE Output_Canvas SHALL render surfaces without selection borders, corner handles, or grid overlays.

### Requirement 4: Output Surface Rendering

**User Story:** As a projection operator, I want the output window surfaces to render content identically to the setup window surfaces, so that what I see in preview matches what the projector displays.

#### Acceptance Criteria

1. THE Output_Canvas Projection_Surface SHALL support the same content types as the Setup_Window Projection_Surface: solid color, image, video, shader effect, and web content.
2. WHEN a shader effect is active on a surface, THE Output_Canvas Projection_Surface SHALL create its own SubViewport and ShaderMaterial instance using the same effect ID and shader parameters.
3. WHEN a video is active on a surface, THE Output_Canvas Projection_Surface SHALL create its own SubViewport and VideoStreamPlayer instance using the same video source path.
4. WHEN shader parameters are changed via the sidebar, THE Output_Canvas Projection_Surface SHALL update its ShaderMaterial parameters to match.
5. THE Output_Canvas Projection_Surface SHALL apply the same fit mode (stretch, fit, fill) and opacity as the Setup_Window Projection_Surface.

### Requirement 5: Toolbar Integration

**User Story:** As a projection operator, I want a clear toolbar control to open/close the output window and select the target display, so that I can manage dual output without memorizing keyboard shortcuts.

#### Acceptance Criteria

1. THE Toolbar SHALL display a "Dual Output" button that opens the Output_Window when clicked while the Output_Window is closed.
2. WHEN the Output_Window is open, THE Toolbar "Dual Output" button SHALL change its label to indicate the active state and close the Output_Window when clicked.
3. THE Toolbar SHALL display the Display_Selector dropdown adjacent to the "Dual Output" button.
4. WHILE the Output_Window is open, THE Display_Selector SHALL be disabled to prevent changing the target display without first closing the Output_Window.

### Requirement 6: Keyboard Shortcut Support

**User Story:** As a projection operator, I want keyboard shortcuts to toggle the output window, so that I can quickly start and stop projection during a live performance.

#### Acceptance Criteria

1. WHEN the operator presses a dedicated keyboard shortcut (Ctrl+D), THE Setup_Window SHALL toggle the Output_Window open or closed.
2. THE existing F11 and Tab shortcuts SHALL continue to toggle the single-window Output_Mode as a fallback for single-display setups.
3. WHEN the Output_Window is open and the operator presses Escape in the Output_Window, THE Output_Window SHALL close.

### Requirement 7: Backward Compatibility with Single-Window Output Mode

**User Story:** As a projection operator using a single display, I want the existing Output Mode to continue working unchanged, so that I can still use the application without a second display.

#### Acceptance Criteria

1. THE existing Output_Mode (F11/Tab toggle) SHALL continue to hide the UILayer and go fullscreen in the Setup_Window when no Output_Window is open.
2. WHILE the Output_Window is open, THE single-window Output_Mode toggle (F11/Tab) SHALL be ignored to prevent conflicting display states.
3. THE existing Escape key behavior in single-window Output_Mode SHALL continue to restore the Setup_Window to its previous window mode.

### Requirement 8: Configuration Persistence

**User Story:** As a projection operator, I want my preferred output display selection to be remembered across sessions, so that I do not have to reconfigure the target display each time I launch the application.

#### Acceptance Criteria

1. WHEN the operator selects a target display in the Display_Selector, THE SurfaceManager SHALL store the selected display index in the configuration data.
2. WHEN a configuration is loaded, THE Display_Selector SHALL restore the previously saved display index if that display is still connected.
3. IF the previously saved display index is no longer available, THEN THE Display_Selector SHALL fall back to the default display selection (secondary display or index 0).
