---
name: bevy-0-19
description: Write and migrate Rust games on Bevy 0.19 (released 2026-06-19, MSRV Rust 1.95). Covers everything that changed from 0.18 — Parley text engine (FontSource, FontSize), resources stored as components, bevy_scene → bevy_world_serialization renames plus new BSN scenes, window exit systems moved to Last (ExitSystems), audio/feature reorganization — and new 0.19 capabilities (EditableText, contact shadows, delayed commands, settings framework). Use when a project's Cargo.toml pins bevy 0.19+, when migrating a Bevy 0.18 project forward, or when compile errors mention FontSize, FontSource, ExitSystems, WorldAsset, or FallbackErrorHandler. For Bevy 0.16–0.18 code the `bevy` skill applies instead; this skill only documents the 0.18 → 0.19 delta on top of it.
---

# Bevy 0.19 Skill

Delta skill on top of the `bevy` (0.18) skill: everything here is what changed in
**Bevy 0.19** (2026-06-19). For ECS fundamentals, idiomatic patterns, and 0.16→0.18
migrations, load the `bevy` skill — those patterns still apply unless overridden below.

## 1. Version context

| Fact | Value |
|---|---|
| Release | 0.19.0, June 19 2026 (1185 PRs) |
| MSRV | **Rust 1.95** — `rustup update stable` first; older toolchains fail with "bevy_ecs@0.19.0 requires rustc 1.95.0" |
| Default features | `default = ["2d", "3d", "ui", "audio"]` — `audio` is no longer implied by `2d`/`3d`/`ui`, it is its own explicit default |
| Still valid | `wav`, `wayland`, `sprite_picking`, `ui_picking` feature names |

## 2. The changes that hit real projects (verified by an actual 0.18 → 0.19 migration)

These four broke a real, plain 2D game; everything else in that project compiled unchanged.
2.4 compiles fine and only breaks visually at runtime — check it whenever padded UI nodes
carry an `ImageNode`.

### 2.1 Text: Cosmic Text → Parley

`TextFont.font` is now a `FontSource` (`From<Handle<Font>>` exists) and `font_size` is a
`FontSize` enum. Both are in the prelude.

```rust
// 0.18
TextFont { font: handle, font_size: 14.0, ..default() }
// 0.19
TextFont { font: handle.into(), font_size: FontSize::Px(14.0), ..default() }
```

- `FontSize` variants include `Px`, `Vh`, `Rem` (responsive sizing).
- `FontSource` variants: `Handle`, `Family`, `Monospace`.
- `TextLayout::new_with_justify/linebreak/no_wrap()` → `TextLayout::justify/linebreak/no_wrap()`.
- `Font::try_from_bytes()` → `Font::from_bytes()` (infallible now).
- New: `LetterSpacing` component, variable font weight/width/style on `TextFont`,
  `EditableText` component (cursor, selection, IME, clipboard).

### 2.2 Window exit systems moved to `Last` — ordering hazard

`close_when_requested`, `exit_on_all_closed`, `exit_on_primary_closed` now run in the
`Last` schedule inside the new `bevy::window::ExitSystems` set. Any of your own `Last`
systems that react to `AppExit` (save-on-exit, cleanup, telemetry flush) must be ordered
after it, or they race and miss the final frame's message:

```rust
app.add_systems(Last, save_on_exit.after(bevy::window::ExitSystems));
```

### 2.3 Resources are components now

`#[derive(Resource)]` internally implements `Component` (resources live on singleton
entities). Consequences:

- **Never derive both** `Component` and `Resource` on one type anymore — split the type.
- Broad queries (`Query<()>`, `Query<Entity>`, `Query<EntityMut>`) now see resource
  entities and can conflict with resource access; add a filter, e.g. `Without<IsResource>`.
- Generic mutable resource access needs `R: Resource<Mutability = Mutable>` on `ResMut<R>`
  / `World::resource_mut()` bounds.
- Enables: lifecycle observers on resources, relationships to resources, resource queries.

### 2.4 `ImageNode` draws in the content box by default

`ImageNode` gained a `visual_box: VisualBox` field (`ContentBox` | `PaddingBox` |
`BorderBox`), default **`ContentBox`**. In 0.18 the image covered the whole node. On any
node that combines an `ImageNode` (9-slice frames, button/panel backgrounds) with
`padding`, the visible image now shrinks onto the padded interior: frames render smaller
than the node, children sit flush against the visible edge, and bottom-padded footers look
clipped. Fix: set `visual_box: VisualBox::BorderBox` (import `bevy::ui::VisualBox`) to
restore the 0.18 look. Image-only icons without padding are unaffected. This is a silent
runtime change — screenshots, not the compiler, catch it.

## 3. Renames you will hit sooner or later

| 0.18 | 0.19 |
|---|---|
| `Scene` / `SceneRoot` / `DynamicScene` / `SceneSpawner` (old bevy_scene) | `WorldAsset` / `WorldAssetRoot` / `DynamicWorld` / `WorldInstanceSpawner` in `bevy_world_serialization` — `bevy_scene` now means the new BSN system |
| `DefaultErrorHandler` / `default_error_handler()` | `FallbackErrorHandler` / `fallback_error_handler()` |
| `init_non_send_resource` / `insert_non_send_resource` / `World::non_send_resource*` | `init_non_send` / `insert_non_send` / `World::non_send*` ("non-send data", not "resource") |
| `System::type_id()` | `System::system_type()` |
| `ExecutorKind::SingleThreaded` etc. | executor instances: `schedule.set_executor(SingleThreadedExecutor::new())` |
| `InputFocus.0` (public field) | `input_focus.get()` / `.set(entity)` / `.clear()` |
| `Skybox { image: handle }` | `Skybox { image: Some(handle) }` |
| `Atmosphere::earthlike()`, camera component | `Atmosphere::earth()`, spawned as its own entity; `bottom_radius`/`top_radius` → `inner_radius`/`outer_radius` |
| `experimental_bevy_feathers` / `experimental_bevy_ui_widgets` features | `bevy_feathers` / `bevy_ui_widgets` (stable; widgets in `ui` collection); `FeathersPlugin` → `FeathersCorePlugin` |
| `ShaderStorageBuffer` | `ShaderBuffer` |
| `ComputedNode::stack_index` | `ComputedStackIndex` component |
| `UiWidgetsPlugins`, `InputDispatchPlugin` added manually | already in `DefaultPlugins` — remove manual adds |
| `Assets::get_mut()` returning `&mut A` | returns `AssetMut<A>`; `AssetEvent::Modified` only fires on real mutation |
| `Ref<T>::clone()` cloning inner | `Ref` is `Copy`; use `ref.as_ref().clone()` for the inner value |
| bevy-internal rand (affects bevy_rand users) | rand 0.10: `RngCore` → `Rng`, old `Rng` → `RngExt` |

gltf: `Handle<StandardMaterial>` from `"file.glb#Material0"` is now `Handle<GltfMaterial>`;
append `/std` to the label for the standard material. `bevy_gltf` is optional/independent.

## 4. New in 0.19 (worth reaching for)

- **BSN scenes**: `bsn!` macro (Rust-like scene notation), `Scene`/`SceneList` traits,
  scene functions with parameters, `#EntityName` cross-references, `SceneComponent` derive.
- **Delayed commands**: `commands.delayed().secs(2.0).spawn(...)`.
- **Observer run conditions**: `.run_if(...)` on observers.
- **Settings framework**: `SettingsPlugin`, `#[derive(SettingsGroup)]`,
  `SaveSettingsDeferred`/`SaveSettingsSync` — consider before hand-rolling config saves.
- **Contact shadows** (screen-space), physically based SSR, rectangular area lights
  (`area_light_luts` feature), `Vignette`/`LensDistortion` post-processing.
- **Perf**: big-scene rendering 2.3–2.6× faster; occlusion culling stable.
- **Tooling**: `DiagnosticsOverlayPlugin` (fps preset), text gizmos (`Gizmos::text/text_2d`),
  `TransformGizmoPlugin` (interactive editor gizmo), `InfiniteGridPlugin`.
- **Render graph is systems now** (`Core2d`/`Core3d` schedules) — custom render nodes
  need porting; see REFERENCE.md.

## 5. Migration workflow (proven order)

1. `rustup update stable` (needs 1.95+), bump `bevy = "0.19"`.
2. `cargo check`; fix in this order: TextFont literals → renames from §3 → the rest via
   [REFERENCE.md](REFERENCE.md).
3. Audit every `Last`-schedule system reading `AppExit` → `.after(ExitSystems)` (§2.2) —
   this one compiles fine and fails silently at runtime, so test a real window close.
4. Types deriving both `Component` + `Resource` → split (§2.3).
5. Runtime-verify text rendering (Parley may lay out slightly differently) and a graceful
   window close, not just the build.

Not changed in 0.19 (verified compiling as-is): `Sprite`/`Camera2d`/`Msaa`, UI `Node` +
`px()`/`percent()`, `ImageNode` 9-slicing, observers (`On<Pointer<Click>>`, `.observe()`),
`Message`/`MessageReader`, states + `DespawnOnExit`, custom `AssetLoader`s,
`WinitSettings`/`UpdateMode`, `ScrollPosition`, `HoverMap`, `PlaybackSettings`/`Volume`,
`TextureAtlasLayout::from_grid`, `children!`.

Full exhaustive change list: [REFERENCE.md](REFERENCE.md).
Official guide: https://bevy.org/learn/migration-guides/0-18-to-0-19/
