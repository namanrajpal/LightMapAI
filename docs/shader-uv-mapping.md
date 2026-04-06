# Shader UV Mapping on Warped Polygons

## The Problem

Shader effects (neon borders, edge glow, breathing frames, etc.) use UV coordinates to compute distance from edges:

```glsl
float d_left = uv.x;
float d_right = 1.0 - uv.x;
float d_top = uv.y;
float d_bottom = 1.0 - uv.y;
float d_edge = min(min(d_left, d_right), min(d_top, d_bottom));
```

This assumes UV space is a clean 0-to-1 rectangle where `uv.x = 0` is the left edge and `uv.x = 1` is the right edge.

When a surface polygon is keystoned (warped into a trapezoid to correct for projector angle), the UV mapping determines whether the shader "follows" the polygon edges or appears distorted.

## How It Works

### Rendering Pipeline

1. Shader effects render into a SubViewport (sized to the polygon's bounding box)
2. The SubViewport texture is mapped onto the Polygon2D via UV coordinates
3. Godot's rasterizer interpolates UVs across the polygon triangles

### UV Mapping Strategy

**4-corner quads (the common case):**
Canonical UVs are used — TL→(0,0), TR→(w,0), BR→(w,h), BL→(0,h) in texture pixel coordinates. This means the shader's UV space is always a perfect rectangle regardless of how the polygon is warped on screen. Edge-distance shaders correctly follow the polygon borders.

**N-corner polygons (5+ corners):**
Bounding-box normalization is used for UVs. Additionally, a polygon-aware edge distance texture (`_edge_distance`) is generated at shader load time. This grayscale texture encodes the normalized distance from each pixel to the nearest polygon edge. Border shaders (neon_border, breathing_frame, edge_glow) sample this texture to compute edge distance instead of using rectangular UV math, so borders correctly follow the polygon shape regardless of corner count.

### Why Not Apply Shaders Directly to the Polygon2D?

We tried applying the ShaderMaterial directly to the Polygon2D (eliminating the SubViewport). This broke because:
- Godot's Polygon2D material pipeline interacts differently with `UV` than a ColorRect in a SubViewport
- The shader's `TIME`, `VERTEX`, and other built-ins behave differently on Polygon2D vs ColorRect
- Many community shaders are written assuming they run on a rectangular Control node

The SubViewport approach is more compatible and predictable.

### SubViewport Sizing

The SubViewport is sized to match the polygon's bounding box dimensions (clamped to 128-2048px) rather than a fixed 1024x1024. This ensures the shader renders at the correct aspect ratio — circles stay circular, patterns keep their proportions.

```gdscript
var bbox := _get_corners_bbox()
var vp_w := int(clampf(bbox.size.x, 128, 2048))
var vp_h := int(clampf(bbox.size.y, 128, 2048))
```

The `_resolution` uniform is set to `Vector2(vp_w, vp_h)` so aspect-aware shaders can compensate.

## Writing Shaders That Work Well With Warped Polygons

1. Use `UV` for edge distance — it maps 0-to-1 across the polygon for quads
2. Use `_resolution` uniform if you need aspect ratio correction
3. Keep effects symmetric — they look best when the polygon is roughly rectangular
4. For border/frame effects, compute distance from all 4 edges using `UV.x`, `1.0 - UV.x`, `UV.y`, `1.0 - UV.y`
5. Avoid hardcoding pixel sizes — use UV-relative values (e.g., `border_thickness = 0.02` not `border_thickness = 20.0`)

## Key Files

- `scripts/projection_surface.gd` — `_load_shader()`, `_update_polygon()`, `_compute_fit_uvs()`
- `shaders/effects/*.gdshader` — all effect shaders
- `autoload/shader_registry.gd` — shader discovery and parameter parsing
