# LightMapAI

**AI-Driven Projection Mapping for Ambient Spatial Computing**

Naman Rajpal · [github.com/namanrajpal/LightMapAI](https://github.com/namanrajpal/LightMapAI)

---

## Abstract

LightMapAI is an open-source system that combines AI-driven shader generation with real-time projection mapping to enable ambient spatial computing. Users describe visual intent in natural language; the system synthesizes GPU shaders and projects them onto calibrated physical surfaces. Our architecture introduces a proxy-based rendering model built on Godot Engine 4.x that performs real-time perspective homography warping with pixel-precise calibration across arbitrary N-point polygon surfaces. The system supports multi-surface management, dual-output projection, and JSON-based configuration serialization. All source code is available under an open-source license to support reproducibility and further research in spatial display systems.

## Motivation

Commercial projection mapping tools (MadMapper, Resolume, TouchDesigner) require expensive licenses and steep learning curves. Artists and researchers with a projector and a creative vision shouldn't need VJ expertise to transform physical spaces. LightMapAI lowers the barrier from specialized technical skill to natural language — anyone can describe a visual and project it onto physical space without learning complex commercial tools.

This work explores the intersection of two domains: **projection mapping** as a spatial display medium, and **generative AI** as a content creation tool. By connecting an LLM directly to a GPU shader pipeline, we enable a workflow where creative intent expressed in plain English becomes a real-time visual projected onto physical geometry.

## Demonstrations

<p align="center">
<img src="docs/image/basic-usage.gif" alt="Basic usage — creating and warping projection surfaces" width="480"><br>
<em>Fig. 1: Surface creation, corner warping, and shader effect application</em>
</p>

<p align="center">
<img src="docs/image/ai-integration.gif" alt="AI integration — generating shaders from natural language" width="480"><br>
<em>Fig. 2: AI-driven shader generation from natural language description</em>
</p>


## System Architecture

```
User Description ──▶ LLM API ──▶ GLSL Shader ──▶ SubViewport Render ──▶ Polygon2D UV Map ──▶ Projector
                                                                              ▲
Corner Calibration ──▶ Homography Matrix ──▶ Canonical UV Mapping ────────────┘
```

The system consists of four core components:

**SurfaceManager** — Central data store for all projection surfaces. Each surface is defined by an N-point polygon (3+ corners), a color, opacity, z-order, and optional content (shader effect, image, video, or web source). Surfaces are serialized as JSON for portability.

**ShaderRegistry** — Discovers, catalogs, and provides shader effects. Shaders in `shaders/effects/` are auto-discovered at startup. Each shader's GLSL uniforms are parsed to auto-generate UI controls (sliders, color pickers, toggles) without any manual configuration.

**AiShaderAgent** — Connects to an Anthropic or OpenAI-compatible LLM API. A system prompt encodes the shader conventions (metadata format, UV mapping, parameter annotations). The LLM generates a complete `canvas_item` shader from a natural language description. Generated shaders are validated for compilation before saving.

**Rendering Pipeline** — Shader effects render into a SubViewport sized to the polygon's bounding box. The SubViewport texture is mapped onto a Polygon2D using canonical UV coordinates (for quads) or bounding-box-normalized UVs (for N-point polygons). This ensures edge-distance shaders correctly follow polygon borders regardless of keystoning. See [docs/shader-uv-mapping.md](docs/shader-uv-mapping.md) for details.

## Key Contributions

1. **Natural language to spatial projection** — Describe a visual effect in plain English, get a GPU shader, project it onto a physical surface. No shader programming required.

2. **N-point polygon surfaces** — Surfaces support arbitrary polygon shapes (3+ corners), not just quads. This enables mapping onto irregular architectural features like walls around windows, L-shaped surfaces, and complex geometry.

3. **Canonical UV mapping for warped quads** — Shader effects use canonical UV coordinates (TL→0,0 TR→1,0 BR→1,1 BL→0,1) regardless of the polygon's screen-space warp. This means edge-distance shaders (borders, glows, frames) correctly follow the polygon edges even under extreme keystoning.

4. **Auto-generated shader UI** — Shader uniforms with `@range` annotations automatically generate sidebar controls. No manual UI wiring needed for new effects.

5. **Open-source, lightweight** — The entire system is under 3 MB, built in GDScript on Godot 4.x, and runs on macOS, Windows, and Linux.


## Built-in Shader Effects

The system ships with 20 shader effects across four categories:

| Category | Effects |
|----------|---------|
| **Plasma** | Classic Plasma, Plasma Fire, Plasma Ocean, Plasma Aurora, Plasma Lava, Plasma Electric |
| **Edge Plasma** | Edge Plasma, Edge Plasma Fire, Edge Plasma Electric, Edge Plasma Pulse, Edge Plasma Rainbow |
| **Borders** | Neon Border, Breathing Frame, Edge Glow, Neon Pulse |
| **Patterns** | Voronoi Cells, Matrix Rain, Electric Cracks, Scan Lines, Candle Flame |

All effects are parameterized with real-time controls. Additional effects can be added by placing `.gdshader` files in `shaders/effects/` or generated via the AI integration.

## Getting Started

```bash
git clone https://github.com/namanrajpal/LightMapAI.git
```

1. Open in **Godot 4.6+** (GL Compatibility renderer)
2. Press **F5** to run
3. Create surfaces, drag corners to warp onto physical objects
4. Select a shader effect from the sidebar, or use **"Add Effects with AI"** to generate one from a description
5. Press **Ctrl+D** for dual output (setup on laptop, projection on secondary display)

### AI Configuration

The AI shader generation connects to an Anthropic or OpenAI-compatible API. Configure in the "Add Effects with AI" dialog:

- **Anthropic** (default): `https://api.anthropic.com/v1/messages` with your API key
- **OpenAI**: `https://api.openai.com/v1/chat/completions`
- **Local Ollama**: `http://localhost:11434/v1/chat/completions` (no API key needed)

Settings are saved to `user://settings/ai_config.json`.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+S` | Save configuration |
| `Ctrl+O` | Load configuration |
| `Ctrl+N` | Add new surface |
| `Ctrl+D` | Toggle dual output |
| `Delete` | Delete selected surface |
| `G` | Toggle grid overlay |
| `L` | Toggle surface lock |
| `B` | Toggle background (dark / white) |
| `]` / `[` | Move surface forward / backward in z-order |
| `1`–`4` | Select corner by index |
| `F11` / `Tab` | Toggle output mode |
| `Escape` | Exit output mode |
| Right-click | Context menu (select overlapping surfaces, lock, grid, corners, delete) |

## Future Work

- OSC / MIDI integration for live performance control
- Audio-reactive shader parameters driven by FFT analysis
- Bezier edge warping for curved surface mapping
- Multi-projector edge blending
- Cue list sequencer for show automation
- BPM sync for music-driven performances
- Multi-step AI agent with compile-test-fix loop

## Technical Details

- **Engine:** Godot 4.x (GL Compatibility renderer)
- **Language:** GDScript
- **Shaders:** Godot Shading Language (GLSL-based)
- **AI Backend:** Anthropic Claude / OpenAI-compatible APIs
- **Platforms:** macOS, Windows, Linux

## License

Open source. See [LICENSE](LICENSE) for details.

---

*Naman Rajpal · [github.com/namanrajpal](https://github.com/namanrajpal)*
