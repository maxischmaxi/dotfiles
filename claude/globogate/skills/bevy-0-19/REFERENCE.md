# Bevy 0.18 → 0.19 — exhaustive breaking-change reference

Compiled from the official migration guide (https://bevy.org/learn/migration-guides/0-18-to-0-19/)
and the release post (https://bevy.org/news/bevy-0-19/). Grouped by domain; entries already
covered in SKILL.md are repeated here only briefly for completeness.

## ECS & resources

- `#[derive(Resource)]` implements `Component`; resources are stored on singleton entities.
  Never derive both on one type. `ReflectResource` is a ZST — use `ReflectComponent`.
- Broad queries (`Query<()>`, `Query<Entity>`, `Query<EntityMut>`) conflict with resource
  access → add filters (e.g. `Without<IsResource>`).
- Mutable generic resource access: `R: Resource<Mutability = Mutable>` bound required for
  `ResMut<R>`, `World::(get_)resource_mut`, `EntityWorldMut::*`, `DeferredWorld::*`,
  `ExtractResourcePlugin`.
- Non-send "resources" renamed to non-send data everywhere:
  `App::init_non_send_resource` → `init_non_send`, `insert_non_send_resource` → `insert_non_send`,
  `World::(get_)non_send_resource(_mut)` → `(get_)non_send(_mut)` (same pattern on
  `DeferredWorld`, `UnsafeWorldCell`, incl. `_by_id` variants).
- `Components`/`ComponentsRegistrator`/`ComponentDescriptor`: `*_resource_*` methods
  deprecated or renamed to component/non-send equivalents
  (`register_resource` → `register_component`, `new_resource()` → `new()`, …).
- `Access`/`FilteredAccess`: component/resource distinction removed — `add_component_read`
  and `add_resource_read` collapse to `add_read` (same for write/has/read_all/is_compatible/
  is_subset families; `*_resources`-only methods removed). `Access::archetypal()` returns
  `&ComponentIdSet` (call `.iter()`).
- `MapEntities` derived by default for resources — remove manual `#[derive(MapEntities)]`.
- `World::clear_entities()` now also clears resources; new `World::clear_all()` clears
  entities + resources + non-send. `World::remove_resource_by_id()` returns `bool`.
- `World::entities_allocator(_mut)()` → `entity_allocator(_mut)()`.
- Remote entity reservation: allocate entity ids without `&World` (thread-friendly).
- `contiguous_iter(_mut)` expose table slices for SIMD.
- Delayed commands: `commands.delayed().secs(d).spawn(...)`.
- Observers accept `.run_if(...)`.
- Self-referential relationships via `allow_self_referential` attribute;
  `RelationshipAccessor` gained `allow_self_referential` + counterpart `ComponentId` fields;
  `ComponentDescriptor::new_with_layout()` takes `Option<RelationshipAccessorInitializer>`.
- Lifecycle observers carry old/new archetypes: destructure
  `EntityComponentsTrigger { components, .. }`; manual construction needs
  `old_archetype: None, new_archetype: None`.
- `Ref<T>` is `Clone + Copy` — `.clone()` copies the `Ref`, not the inner value.

## Systems & scheduling

- System param validation happens when fetching data (not at schedule build) — custom
  `SystemParam`/`System` impls may need updates.
- `System::type_id()` → `System::system_type()`.
- `ExecutorKind` removed: `schedule.set_executor(SingleThreadedExecutor::new())` /
  `MultiThreadedExecutor::new()` / `default_executor()`. `SystemExecutor` is a public trait;
  `SystemSchedule::systems` is `pub`.
- `SystemBuffer::queue()` is now a required trait method.
- `DefaultErrorHandler` → `FallbackErrorHandler`; `default_error_handler()` →
  `fallback_error_handler()`.

## Windowing, states, input

- `close_when_requested`, `exit_on_all_closed`, `exit_on_primary_closed` run in `Last`
  within the `ExitSystems` set — order your own exit-reacting `Last` systems `.after()` it.
- `DespawnOnEnter`/`DespawnOnExit` can trigger during same-state transitions.
- `InputFocus`: fields private → `get()`/`set(entity)`/`clear()`; `InputFocusPlugin` added;
  `InputDispatchPlugin` and `UiWidgetsPlugins` are part of `DefaultPlugins` now.
- Picking: `bevy_picking` feature no longer pulls `bevy_input_focus`; focus-picking is tied
  to `ui_picking` (in the `ui` collection). Without bevy_ui: depend on `bevy_input_focus`
  with its `bevy_picking` feature.
- New `PanCamera` component (mouse panning).

## Text & UI

- Text engine: Cosmic Text → Parley. `TextFont { font: FontSource, font_size: FontSize }`
  (`handle.into()`, `FontSize::Px(..)`; also `Vh`, `Rem`). `FontSource::{Handle, Family, Monospace}`.
- `TextRoot`/`TextSpanAccess`/`TextSpanComponent` → `TextSection`; `read_span()` →
  `get_text()`, `write_span()` → `get_text_mut()`.
- `PositionedGlyph::span_index` → `section_index`; `byte_index`/`byte_length` removed.
- `Font::try_from_bytes()` → `Font::from_bytes()` (infallible);
  `TextPipeline::map_handle_to_font_id/get_font_id` removed; font atlases not auto-cleared
  on asset removal.
- `TextLayout::new_with_justify/linebreak/no_wrap` → `justify/linebreak/no_wrap`.
- `ComputedTextBlock::needs_rerender(is_viewport_size_changed, is_rem_size_changed)`.
- `Measure::measure()`: `style` param removed (use `MeasureArgs::style`); `MeasureArgs`
  `width`/`height` → `known_width`/`known_height`.
- New: `EditableText` (cursor/selection/IME/multiline/clipboard), `LetterSpacing`,
  variable font weight/width/style.
- Core widget prefix dropped: `CoreScrollbarThumb` → `ScrollbarThumb`,
  `CoreScrollbarDragState` → `ScrollbarDragState`, `CoreSliderDragState` → `SliderDragState`.
  `ScrollbarThumb` no longer has `Node`; laid out post-layout; gained `border`/`border_radius`.
- `Node::direction` field (inline axis, default `InlineDirection::Ltr`).
- Feathers → BSN: spawn functions renamed (`button()` → `button_bundle()`), `button` no
  longer sets `flex_grow`, `button`/`checkbox`/`radio` take a `caption`;
  `FeathersPlugin` → `FeathersCorePlugin`.
- UI debug: `UiDebugOptions` split into `GlobalUiDebugOptions` resource + `UiDebugOptions`
  component; new outline_* bool fields (set extras to false for pre-0.19 look).
  `GlobalUiDebugOverlay` resource / `UiDebugOverlay` component split.
- `ComputedNode::stack_index` → `ComputedStackIndex` component.
- `ViewportNode::camera` is `Option<Entity>`.
- New a11y: `AccessibleLabel`. New `DiagnosticsOverlayPlugin` with `fps()` etc. presets.

## Scenes & assets

- Old scene system renamed (`bevy_scene` → `bevy_world_serialization`); `bevy_scene` is the
  new BSN system. `Scene`→`WorldAsset`, `SceneRoot`→`WorldAssetRoot`,
  `DynamicScene`→`DynamicWorld`, `DynamicSceneBuilder`→`DynamicWorldBuilder`,
  `DynamicSceneRoot`→`DynamicWorldRoot`, `SceneInstanceReady`→`WorldInstanceReady`,
  `SceneLoader`→`WorldAssetLoader`, `ScenePlugin`→`WorldSerializationPlugin`,
  `SceneSpawner`→`WorldInstanceSpawner`, `SceneFilter`→`WorldFilter`, error types likewise.
- `DynamicWorldBuilder::from_world(world, &type_registry)` — type registry now explicit.
- BSN: `bsn!`/`bsn_list!` macros, scene functions with params, `queue_spawn_scene` (waits
  for deps) vs `spawn_scene` (immediate), `asset_value()` inline assets, `#EntityName`
  references, `FromTemplate`/`Template` traits, `SceneComponent` derive.
- `AssetPath::resolve/resolve_embed` take `&AssetPath` (convenience: `resolve_str`,
  `resolve_embed_str`); `get_full_extension()` returns `Option<&str>`.
- `Assets::get_mut()` returns `AssetMut<A>`; `AssetEvent::Modified` fires only on actual
  mutation.
- Asset saving: `SavedAsset` two lifetimes, `AssetSaver` takes `AssetPath`;
  `SavedAssetBuilder`, `save_using_saver()`; handle (de)serialization via
  `HandleSerializeProcessor`/`HandleDeserializeProcessor`.
- `Reader::seekable()` required; `AsyncSeekForward` deleted.
- glTF: `bevy_gltf` optional/independent of `bevy_pbr`; material labels yield
  `Handle<GltfMaterial>`, `#Material0/std` for `StandardMaterial`;
  `GltfExtensionHandler::on_material`/`on_spawn_mesh_and_material` get `material_label`.

## Rendering (only relevant with custom render code)

- Render graph replaced by ECS systems/schedules (`Core2d`, `Core3d`); custom `Node` impls
  must be ported. `RenderErrorHandler` + `RenderErrorPolicy::{Recover, StopRendering, Ignore}`.
- `RenderSystems::ManageViews` split into `CreateViews`/`Specialize`/`PrepareViews`;
  post-process sets split into `EarlyPostProcess`/`PostProcess` (2D and 3D);
  `shadow_pass` split into `per_view_shadow_pass`/`shared_shadow_pass`.
- Phases: change-list based specialization (`DirtySpecializations`), sorted phases use
  `IndexMap`, `SortedRenderPhase::add` → `add_transient`/`add_retained`.
- `MeshPipelineKey::from_primitive_topology_and_strip_index(topology, index_format)` (also
  `Mesh2dPipelineKey` needs STRIP_INDEX_FORMAT bits). Mesh view bind group layout changed.
  `RenderMeshInstance` fields behind accessor methods.
- `MeshPipelineViewLayouts`/`MeshPipeline` etc. created in `RenderStartup` — order after
  `MeshPipelineSystems`.
- Moves: `AlphaMode`, material/pipeline key types → `bevy_material`; `Hdr` → `bevy_camera`
  (not extracted; use `ExtractedCamera::hdr`); `Skybox`, `Atmosphere`, light gizmos →
  `bevy_light`; `Frustum` internals → `bevy_math::primitives::ViewFrustum` (+ `HalfSpace`);
  `define_atomic_id` → `bevy_utils`; `UvChannel` → `bevy_mesh`;
  `ViewTransmissionTexture`/`Transmissive3d` → `bevy_pbr`.
- `Camera3d` transmission fields → `ScreenSpaceTransmission` component;
  `ScreenSpaceTransmissionQuality` no longer a `Resource`.
- `Image::pixel_bytes(_mut)/pixel_data_offset` return `Result<_, TextureAccessError>`.
- `TextureFormat::bevy_default()` deprecated → `ExtractedView::target_format`;
  `ViewTarget::is_hdr()` removed; `PipelineCacheError` → `ShaderCacheError`;
  `ShaderStorageBuffer` → `ShaderBuffer`; `DataFormat` → `TextureChannelLayout`.
- `MeshMorphWeights` is an enum (`Value { weights }` / `Reference(Entity)`); `MorphPlugin`
  removed; morph targets stored in meshes.
- `Skybox::image: Option<Handle<Image>>`. Bloom luma now computed in linear space (looks
  slightly different). Occlusion culling stable. Contact shadows, PB-SSR, area lights
  (`area_light_luts`), `Vignette`, `LensDistortion`, parallax-corrected cubemaps new.
- `FullscreenMaterial`: `run_in/run_after/run_before` → single
  `schedule_configs(system) -> ScheduleConfigs<BoxedSystem>`.
- `PlaneMeshBuilder`: `subdivisions` field → `subdivisions(n)` method
  (`subdivisions_x`/`subdivisions_z` internally).
- `WgpuSettingsPriority::Compatibility` → `WebGPU` (`WGPU_SETTINGS_PRIO=webgpu`).
- `EasyScreenRecordPlugin` requires `output_dir` field.

## Audio & dependencies

- rodio 0.22 / cpal 0.17. Feature set: default `vorbis`; `wav`, `mp3`, `mp4`/`aac`, `flac`;
  symphonia backends (`symphonia-flac`/`-vorbis`/`-wav`); `audio-all-formats` collection.
  `Decodable::DecoderItem` removed (`rodio::Sample` = `f32`). `android_shared_stdcxx` gone;
  min Android API 26.
- `audio` no longer implied by `2d`/`3d`/`ui`; it is an explicit default feature.
- Feature moves: `bevy_window` → `common_api`, `bevy_input_focus` → `ui_api`,
  `custom_cursor` → `default_platform`. `experimental_bevy_feathers` → `bevy_feathers`,
  `experimental_bevy_ui_widgets` → `bevy_ui_widgets`, `experimental_bevy_gltf` removed.
- rand 0.10 (inside bevy): `RngCore` → `Rng`, `Rng` → `RngExt`. glam/uuid bumped.
- `bevy_transform`: `bevy_log` feature removed (tracing via `trace`); parallel propagation
  needs explicit `multi_threaded`.
- Web: dropping a `Task<T>` cancels it on wasm — `task.detach()` for fire-and-forget.

## Reflection & math

- `bevy_reflect` reorganized into modules (`structs`, `enums`, `list`, `map`, `set`,
  `array`, `tuple`, `tuple_struct`) — e.g. `Struct` trait lives in `structs`.
- `DynamicStruct::index_of()` → `Struct::index_of_name()`; `FieldIter` yields
  `(&str, &dyn PartialReflect)`.
- `Interned<T>` requires `Internable` on all instances.
- `Affine3::to_transpose()`/`inverse_transpose_3x3()` behind `Affine3Ext` extension trait.

## New feature highlights (release post)

- BSN next-gen scenes; app settings framework (`SettingsPlugin`, `SettingsGroup` derive,
  `SaveSettingsDeferred`/`SaveSettingsSync`).
- Big-scene render perf 2.3–2.6×; GPU light clustering; parallel visibility.
- Text input, richer text, text gizmos (`Gizmos::text/text_2d`), interactive
  `TransformGizmoPlugin`, `InfiniteGridPlugin`, `DiagnosticsOverlayPlugin`.
- White furnace test compliance (metallic materials absorb less energy — scenes may look
  slightly brighter/different).
