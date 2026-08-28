---
name: bevy
description: Build, extend, and migrate Rust games with the Bevy ECS engine. Use this skill whenever the user edits or generates Bevy code (Cargo.toml uses `bevy`, files import `bevy::`, `#[derive(Component)]`, `#[derive(Resource)]`, `#[derive(Event)]`, `Query<...>`, `Commands`, `App::new()`, observers, systems, plugins). Default target is Bevy 0.18 (released 2026-01-13). This skill covers ECS fundamentals, idiomatic patterns, performance, and the breaking changes across 0.16 → 0.17 → 0.18 so code written for older versions is migrated correctly.
---

# Bevy Game Engine Skill

Bevy is a data-driven Rust game engine built on an ECS (Entity Component System) core. This skill makes Claude produce idiomatic **Bevy 0.18** code and correctly migrate / recognize older 0.16 and 0.17 patterns.

## 1. When to use this skill

Activate on any of these signals:
- `Cargo.toml` depends on `bevy`, `bevy_ecs`, `bevy_app`, `bevy_render`, or a `bevy_*` crate
- Files import `use bevy::` or `use bevy_ecs::`
- Derives: `#[derive(Component)]`, `#[derive(Resource)]`, `#[derive(Event)]`, `#[derive(EntityEvent)]`, `#[derive(Message)]`, `#[derive(States)]`, `#[derive(SubStates)]`, `#[derive(Bundle)]`, `#[derive(Reflect)]`, `#[derive(QueryData)]`
- Types: `App`, `Plugin`, `World`, `Commands`, `Query`, `Res`, `ResMut`, `Local`, `Single`, `Entity`, `EntityRef`, `EntityMut`, `Schedule`, `SystemSet`, `Trigger`, `On`, `Observer`, `MessageReader`, `MessageWriter`, `EventReader`, `EventWriter`
- Attributes: `#[require(...)]`, `#[relationship(...)]`, `#[relationship_target(...)]`, `#[component(...)]`, `#[entity_event(...)]`
- Schedules: `Startup`, `Update`, `FixedUpdate`, `PostUpdate`, `OnEnter`, `OnExit`, `RenderStartup`
- User mentions "Bevy", "ECS game", "WGSL shader in my Bevy project", etc.

## 2. Version context — what's current

| Version | Released    | Status            |
| ------- | ----------- | ----------------- |
| 0.18    | 2026-01-13  | **current**, default target |
| 0.17    | 2025-09-30  | recent, common in published code |
| 0.16    | 2025-04-24  | still seen in older repos |
| ≤ 0.15  | pre-2025    | significantly different API — migrate before editing |

**Default to 0.18** unless the crate's `Cargo.toml` pins an older version. If you see 0.16 / 0.17 code that needs to be edited and the user hasn't asked for a migration, match the version they're on, but flag any obviously broken migrations.

## 3. Minimal working skeleton

### `Cargo.toml`
```toml
[package]
name = "my_game"
version = "0.1.0"
edition = "2024"

[dependencies]
bevy = "0.18"

# Dev-only: dynamic_linking gives 2–10× faster incremental rebuilds.
# Keep it out of [dependencies] so release builds don't inherit it.
[features]
dev = ["bevy/dynamic_linking"]

# Optimize dependencies in dev too — huge perf win for Bevy iteration.
[profile.dev.package."*"]
opt-level = 2

[profile.release]
lto = "thin"
codegen-units = 1
```

### `src/main.rs`
```rust
use bevy::prelude::*;

fn main() -> AppExit {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_systems(Startup, setup)
        .add_systems(Update, rotate_cube)
        .run()
}

#[derive(Component)]
struct Spinner;

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
) {
    commands.spawn((Camera3d::default(), Transform::from_xyz(0.0, 2.0, 5.0).looking_at(Vec3::ZERO, Vec3::Y)));
    commands.spawn((DirectionalLight::default(), Transform::from_xyz(4.0, 8.0, 4.0).looking_at(Vec3::ZERO, Vec3::Y)));
    commands.spawn((
        Mesh3d(meshes.add(Cuboid::default())),
        MeshMaterial3d(materials.add(Color::srgb(0.3, 0.6, 0.9))),
        Spinner,
    ));
}

fn rotate_cube(time: Res<Time>, mut q: Query<&mut Transform, With<Spinner>>) {
    for mut t in &mut q {
        t.rotate_y(time.delta_secs());
    }
}
```

Notes:
- `App::run()` returns `AppExit` in modern Bevy (use as `main`'s return type, or `let _ = App::new()...run();`).
- `delta_secs()` is the current name (old `delta_seconds()` was deprecated).
- `Mesh3d(handle)` / `MeshMaterial3d(handle)` are newtypes — spawn the handle, Bevy's required components pull in `Transform`, `Visibility`, etc.

---

## 4. ECS core concepts (Bevy 0.18)

### 4.1 Entity, Component, System, Resource

```rust
#[derive(Component)]
struct Position(Vec2);

#[derive(Component)]
struct Velocity(Vec2);

#[derive(Resource, Default)]
struct Score(u32);

fn physics(time: Res<Time>, mut q: Query<(&mut Position, &Velocity)>) {
    for (mut p, v) in &mut q {
        p.0 += v.0 * time.delta_secs();
    }
}
```

- Components are `Send + Sync + 'static` structs. Default storage is `Table` (fast iteration); use `#[component(storage = "SparseSet")]` when add/remove churn dominates.
- Resources are type-keyed singletons. Use `init_resource::<T>()` (needs `Default`) or `insert_resource(value)`.
- Systems are plain `fn`s whose parameters all implement `SystemParam`.

### 4.2 Required Components — the idiomatic replacement for Bundles

Since 0.15 (matured in 0.16+), declare dependencies with `#[require(...)]` directly on the component. Missing required components are inserted automatically when you spawn the parent component. This replaces most `*Bundle` types.

```rust
#[derive(Component, Default)]
struct Health(f32);

#[derive(Component, Default)]
struct Mana(f32);

#[derive(Component)]
#[require(Transform, Visibility, Health, Mana = Mana(100.0))]
struct Player;

// Spawning Player auto-inserts Transform, Visibility, Health::default(), Mana(100.0).
commands.spawn(Player);

// Override any required component by providing it explicitly in the tuple:
commands.spawn((Player, Transform::from_xyz(5.0, 0.0, 0.0), Health(50.0)));
```

Bundles (tuples of components, or `#[derive(Bundle)]` structs) still work — but `*Bundle` structs like `SpriteBundle`, `NodeBundle`, `Camera2dBundle` are **gone**. Write `commands.spawn(Sprite::from_image(handle))` directly; `Transform`/`Visibility`/etc. come in via `#[require]`.

### 4.3 App, Plugins, Schedules

```rust
use bevy::prelude::*;

pub struct GameplayPlugin;

impl Plugin for GameplayPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Score>()
            .add_event::<PlayerJumped>()      // Observer-style Event (trigger)
            .add_message::<DamageDealt>()     // buffered Message (writer/reader)
            .init_state::<AppState>()
            .add_systems(Startup, spawn_player)
            .add_systems(Update, (input, physics, ui).chain())
            .add_systems(FixedUpdate, fixed_physics)
            .add_observer(on_player_jump);
    }
}

fn main() -> AppExit {
    App::new().add_plugins((DefaultPlugins, GameplayPlugin)).run()
}
```

Built-in schedules in execution order per frame:
1. `First`, `PreStartup`, `Startup`, `PostStartup` (once)
2. `First`
3. `PreUpdate`
4. `StateTransition` (runs `OnExit` → `OnTransition` → `OnEnter`)
5. `RunFixedMainLoop` → loops (`FixedFirst`, `FixedPreUpdate`, `FixedUpdate`, `FixedPostUpdate`, `FixedLast`) until accumulated time is drained
6. `Update`
7. `PostUpdate`
8. `Last`

Put physics / gameplay logic that must be deterministic in `FixedUpdate`. Put input, rendering-adjacent interpolation, and UI in `Update`.

### 4.4 Queries — shape, filters, access

```rust
fn examples(
    q1: Query<&Transform>,                                  // read-only
    mut q2: Query<&mut Transform>,                          // mutable
    q3: Query<(Entity, &Health, Option<&PlayerName>)>,      // tuple + optional
    q4: Query<&Transform, (With<Player>, Without<Frozen>)>, // filter
    q5: Query<&Transform, Or<(With<Player>, With<Enemy>)>>, // disjunction
    q6: Query<&Transform, Added<Transform>>,                // just-added this frame
    q7: Query<&Transform, Changed<Transform>>,              // added-or-mutated
    q8: Query<(Entity, Has<Shielded>)>,                     // bool without payload
    q9: Single<&Transform, With<Player>>,                   // exactly-one assertion
) {}
```

Common methods:

| Method | Purpose |
|---|---|
| `&q` / `&mut q` (iterator) | iterate all matches |
| `q.iter()` / `q.iter_mut()` | same, explicit |
| `q.par_iter()` / `q.par_iter_mut()` | rayon-parallel |
| `q.single()` / `q.single_mut()` | returns `Result`; error on 0 or 2+ matches (since 0.16) |
| `q.get(e)` / `q.get_mut(e)` | O(1) fetch by `Entity` |
| `q.get_many([e1, e2])` | bulk fetch, errors if any missing |
| `q.iter_many(entities)` / `iter_many_mut(entities)` | iterate a provided `Entity` collection |
| `q.iter_combinations::<K>()` | unique K-tuples — pairwise collision checks |
| `q.is_empty()` / `q.contains(e)` | cheap existence checks |
| `Single<D, F>` as a param | asserts exactly one — system skipped if unmet |

Custom `QueryData` derives are encouraged for reusable projections:

```rust
#[derive(QueryData)]
#[query_data(derive(Debug))]
struct PlayerView<'w> {
    entity: Entity,
    name: &'w Name,
    hp: &'w Health,
}

fn report(players: Query<PlayerView>) {
    for p in &players { info!("{:?} {:?} HP", p.name, p.hp); }
}
```

### 4.5 Commands (deferred) vs World (immediate)

`Commands` queues mutations; they apply at a sync point (end of a system, or at `.chain()` boundaries, or explicit `ApplyDeferred`). A system that takes `&mut World` (an **exclusive system**) mutates immediately but cannot run in parallel with anything.

```rust
fn spawn_stuff(mut commands: Commands) {
    let id = commands.spawn((Name::new("Hero"), Health(100.0))).id();
    commands.entity(id).insert(Velocity(Vec2::ZERO));
    commands.entity(id).remove::<Stunned>();
    commands.entity(id).despawn();                  // no *_recursive: children cascade
    commands.insert_resource(Difficulty::Hard);
    commands.trigger(GameOver { score: 10 });       // fire an Event (observer-style)
    commands.run_system(cached_system_id);          // one-shot system
}
```

Key gotcha: **Commands are deferred.** Reading the just-spawned entity in the *same* system (or a peer system run in parallel) will miss it. Fix: order the consumer `after()` the producer with `.chain()` (or use an observer).

### 4.6 Events vs Messages — the 0.17 split (still current in 0.18)

0.17 split the old unified `Event` trait into two complementary concepts:

**Event** — push-based, handled synchronously by observers.
```rust
#[derive(Event)]
struct GameOver { score: u32 }

// Fire it
commands.trigger(GameOver { score: 42 });

// Handle it — param is `On<E>` (was `Trigger<E>` in 0.16)
fn on_game_over(over: On<GameOver>) {
    info!("final score: {}", over.score);
}
app.add_observer(on_game_over);
```

**EntityEvent** — an Event targeted at a specific entity; supports hierarchy propagation.
```rust
#[derive(EntityEvent)]
struct Clicked { entity: Entity }

#[derive(EntityEvent)]
#[entity_event(propagate)]       // bubbles up ChildOf
struct Damage { entity: Entity, amount: i32 }

fn on_click(click: On<Clicked>, mut commands: Commands) {
    commands.entity(click.entity).insert(Selected);
}

// Global observer for all Clicked events
app.add_observer(on_click);

// Entity-scoped observer — fires only when triggered on this entity
commands.spawn(Mine).observe(|_: On<Clicked>, mut cmd: Commands, e: Entity| {
    cmd.entity(e).despawn();
});

// Fire it
commands.trigger(Clicked { entity: some_entity });

// Stop propagation inside a handler
fn on_damage(mut dmg: On<Damage>) {
    if should_absorb() { dmg.propagate(false); }
}
```

Component **lifecycle** observers use short event names and a component type:
```rust
fn on_add_player(add: On<Add, Player>, q: Query<&Transform>) {
    let t = q.get(add.entity).unwrap();
    info!("player spawned at {t:?}");
}
fn on_remove_player(_: On<Remove, Player>) { /* ... */ }
// Also: On<Insert, C>, On<Replace, C>, On<Despawn, C>
```

**Message** — pull-based, buffered, drained via reader (the old "buffered events").
```rust
#[derive(Message, Debug)]
struct DamageDealt { target: Entity, amount: i32 }

app.add_message::<DamageDealt>();

fn attacker(mut w: MessageWriter<DamageDealt>) {
    w.write(DamageDealt { target: e, amount: 10 });
}

fn logger(mut r: MessageReader<DamageDealt>) {
    for m in r.read() { info!("{m:?}"); }
}
```

A single type *may* derive both `Event` and `Message` if you genuinely need both roles, but prefer one.

**Rule of thumb:**
- **Event / Observer** — immediate reaction, single handler owns the decision, chain of cause-and-effect (clicks, damage, game-over).
- **Message** — fan-out logging, decoupled producers/consumers, many readers, buffered across frames (analytics, achievements, replay log).

### 4.7 Observers in depth

Observers are systems attached to events. Register globally (`app.add_observer(sys)`) or scope to an entity (`entity.observe(sys)` / `Observer::new(sys).watch_entity(e)`).

```rust
// A run-condition on an observer
app.add_observer(
    (|ev: On<Damage>, mut cmd: Commands| {
        cmd.entity(ev.entity).insert(Hurt);
    })
    .run_if(|cfg: Res<Config>| cfg.damage_enabled),
);

// Full SystemParam access inside observers: Query, Res, Commands, etc.
fn explode(ev: On<Explode>, mut cmd: Commands, bombs: Query<&Bomb>) {
    if let Ok(b) = bombs.get(ev.entity) { /* ... */ cmd.entity(ev.entity).despawn(); }
}
```

### 4.8 Component hooks

Synchronous callbacks fired on lifecycle transitions; run inside the ECS mutation path with a restricted `DeferredWorld`. Prefer observers unless you *must* react synchronously (e.g., index bookkeeping).

```rust
#[derive(Component)]
#[component(on_add = on_add_mine, on_remove = on_remove_mine)]
struct Mine;

fn on_add_mine(mut world: DeferredWorld, ctx: HookContext) {
    // ctx.entity, ctx.component_id, ctx.caller available
    world.commands().entity(ctx.entity).insert(Hazard);
}
fn on_remove_mine(_: DeferredWorld, _: HookContext) {}
```

Lifecycle order: `on_add` → `on_insert` → (later) `on_replace` → `on_remove` → `on_despawn`.

### 4.9 Relationships (including parent/child)

A relationship is two linked components kept in sync by built-in hooks. The hierarchy pair `ChildOf` / `Children` is built on this machinery.

```rust
// Parent/child (prelude)
let root = commands.spawn_empty().id();
commands.spawn(ChildOf(root));

// Bulk spawn children (no limit now; up to ~1400 since 0.17)
commands.spawn((Name::new("root"), children![
    (Name::new("a"),),
    (Name::new("b"),),
]));

// Traversal helpers on Query<&Children> / Query<&ChildOf>
for d in children_q.iter_descendants(root) { /* ... */ }
for a in child_of_q.iter_ancestors(entity)  { /* ... */ }

// Custom relationship
#[derive(Component)]
#[relationship(relationship_target = TargetedBy)]
struct Targeting(Entity);

#[derive(Component)]
#[relationship_target(relationship = Targeting)]
struct TargetedBy(Vec<Entity>);

commands.spawn(Name::new("archer"))
    .with_related::<Targeting>(Name::new("goblin"));
```

Despawning a parent cascades to descendants automatically — no `despawn_recursive()`; just `despawn()`.

### 4.10 States

```rust
#[derive(States, Default, Debug, Clone, PartialEq, Eq, Hash)]
enum AppState { #[default] Menu, InGame, Paused }

app.init_state::<AppState>()
   .add_systems(OnEnter(AppState::InGame), spawn_world)
   .add_systems(OnExit(AppState::InGame),  cleanup_world)
   .add_systems(Update, tick.run_if(in_state(AppState::InGame)));

fn start(mut next: ResMut<NextState<AppState>>) { next.set(AppState::InGame); }
```

**SubStates** (depend on a parent value) and **ComputedStates** (derived from other state) avoid sync bugs:

```rust
#[derive(SubStates, Clone, PartialEq, Eq, Hash, Debug, Default)]
#[source(AppState = AppState::InGame)]
enum CombatPhase { #[default] Scouting, Engaged }
```

State-scoped auto-cleanup: spawn entities with `DespawnOnExit(AppState::Menu)` (or `DespawnOnEnter`) and Bevy despawns them at the transition. (This replaces the older `StateScoped`.)

### 4.11 Change detection

```rust
fn newly(q: Query<&Name, Added<Player>>) { /* just added this frame */ }
fn moved(q: Query<&Transform, Changed<Transform>>) { /* added or DerefMut'd */ }

fn ref_sees_flags(q: Query<Ref<Health>>) {
    for h in &q {
        if h.is_changed() && !h.is_added() { /* truly changed */ }
    }
}

fn resources(cfg: Res<Config>) { if cfg.is_changed() { reconfigure(); } }
```

Avoid false positives — taking `&mut T` sets the `Changed` flag even if you write the same value. Use `.set_if_neq(new)` on components/resources, or compare before assigning.

### 4.12 Run conditions

```rust
use bevy::time::common_conditions::on_timer;

app.add_systems(Update, (
    autosave.run_if(on_timer(Duration::from_secs(60))),
    ui.run_if(resource_exists::<UiConfig>),
    spawn.run_if(any_with_component::<SpawnSignal>),
    dbg.run_if(input_just_pressed(KeyCode::F3)),
    tick.run_if(in_state(AppState::InGame).and(not(paused))),
));

fn paused(p: Option<Res<Paused>>) -> bool { p.is_some() }
```

Built-in conditions: `resource_exists`, `resource_changed`, `resource_equals`, `any_with_component`, `in_state`, `state_changed`, `input_just_pressed`, `on_timer`, `on_event`, `on_message`, `not(cond)`, `cond.and(other)`, `cond.or(other)`.

**Gotcha:** a system gated off by a run condition doesn't advance its `MessageReader` cursor — messages queued while the system is paused still accumulate until read (or the ring buffer wraps, losing them).

### 4.13 Parallelism

The scheduler parallelizes systems whose `SystemParam` accesses don't conflict. Two `Query<&mut T>` in the same system on overlapping archetypes are rejected at runtime — use `ParamSet` to access them one at a time:

```rust
fn touch(mut set: ParamSet<(
    Query<&mut Health, With<Ally>>,
    Query<&mut Health, With<Enemy>>,
)>) {
    for mut h in set.p0().iter_mut() { h.0 += 1.0; }
    for mut h in set.p1().iter_mut() { h.0 -= 1.0; }
}

fn parallel(mut q: Query<(&mut Transform, &Velocity)>, time: Res<Time>) {
    q.par_iter_mut().for_each(|(mut t, v)| {
        t.translation += v.0.extend(0.0) * time.delta_secs();
    });
}
```

### 4.14 Reflection

Required for scene (de)serialization, `bevy_remote` (BRP), inspector tools, hot-reload workflows. Auto-registration (0.17+) removes most boilerplate.

```rust
#[derive(Component, Reflect, Default)]
#[reflect(Component)]
struct Stats { hp: i32, mp: i32 }

#[derive(Resource, Reflect, Default)]
#[reflect(Resource)]
struct Difficulty(f32);
```

Generic instantiations still need manual registration: `app.register_type::<Inventory<Gem>>()`. Since 0.18, `#[reflect(...)]` accepts **only** parentheses — not `#[reflect[Clone]]` or `#[reflect{Clone}]`.

---

## 5. Rendering & UI — the essentials

### 5.1 Cameras, lights, meshes

```rust
commands.spawn((Camera3d::default(), Transform::from_xyz(0.0, 2.0, 5.0).looking_at(Vec3::ZERO, Vec3::Y)));
commands.spawn((Camera2d::default(),));                       // for 2D games
commands.spawn((DirectionalLight::default(), Transform::from_xyz(4.0, 8.0, 4.0)));
commands.spawn((Mesh3d(mesh_handle), MeshMaterial3d(mat_handle), Transform::default()));
commands.spawn((Sprite::from_image(asset_server.load("foo.png")),));
```

- `Hdr` is its own component (0.17+): `commands.spawn((Camera3d::default(), Hdr))`.
- Post-processing like `Bloom`, `Tonemapping`, `DepthOfField`, `Fxaa`, `TemporalAntiAlias` are components added on the camera entity.
- `Anchor` is required on `Sprite`; variants are `SCREAMING_CASE` associated consts (`Anchor::BOTTOM_LEFT`).
- `Aabb` is recomputed automatically in 0.18 when a mesh / sprite changes; opt out with the `NoAutoAabb` component.
- `RenderTarget` is a **component** in 0.18 (not a field on `Camera`).

### 5.2 UI — entity-based

```rust
use bevy::ui::{Val, px, percent, vh};

commands.spawn((
    Node {
        width: percent(100.0),
        height: vh(100.0),
        justify_content: JustifyContent::Center,
        align_items: AlignItems::Center,
        padding: px(16).all(),
        ..default()
    },
    BackgroundColor(Color::srgb(0.1, 0.1, 0.15)),
    children![
        (
            Button,
            Node { width: px(160), height: px(40), ..default() },
            BackgroundColor(Color::srgb(0.2, 0.5, 0.8)),
            children![(Text::new("Play"), TextFont::from_font_size(18.0))],
        ),
    ],
));
```

- `Val` helpers (`px`, `percent`, `vw`, `vh`, `vmin`, `vmax`, `auto`) land in 0.17+. Chain: `px(8).all()`, `percent(20).horizontal().with_top(px(10))`, `vw(10).left()`.
- `BorderColor::all(color)` with per-side fields (`top`, `right`, `bottom`, `left`).
- `BorderRadius` in 0.18 is on `Node` (`node.border_radius = ...`), not a separate component.
- Prefer **observers** for interactions rather than polling `Interaction` — attach with `.observe(|_: On<Pointer<Click>>, ...| {})`.
- Picking events renamed in 0.17: `Pointer<Pressed>` → `Pointer<Press>`, `Pointer<Released>` → `Pointer<Release>`.
- 0.18 adds `Popover`, `MenuPopup`, `RadioGroup`, and `AutoDirectionalNavigation` for gamepad/keyboard UI nav.

### 5.3 Text (0.18)

```rust
commands.spawn((
    Text::new("Hello"),
    TextFont { font: handle, font_size: 24.0, weight: FontWeight::BOLD, ..default() },
    LineHeight::from_px(32.0),          // separate component in 0.18
    TextColor(Color::WHITE),
    // Optional: Strikethrough, Underline, StrikethroughColor, UnderlineColor
));
```

- `LineHeight` is its own component (moved out of `TextFont`).
- `FontWeight` newtype (1–1000), `FontFeatures` for OpenType features.
- `JustifyText` was renamed to `Justify` in 0.17.

### 5.4 Input

```rust
fn controls(
    keys:  Res<ButtonInput<KeyCode>>,
    mouse: Res<ButtonInput<MouseButton>>,
    chars: Res<ButtonInput<Key>>,           // layout-aware (0.17+)
    gamepads: Query<&Gamepad>,
) {
    if keys.just_pressed(KeyCode::Space) { jump(); }
    if mouse.pressed(MouseButton::Left)   { fire(); }
    for pad in &gamepads {
        if pad.just_pressed(GamepadButton::South) { interact(); }
    }
}
```

### 5.5 Assets

```rust
#[derive(Resource)]
struct GameAssets { player: Handle<Image>, music: Handle<AudioSource> }

fn preload(mut cmd: Commands, server: Res<AssetServer>) {
    cmd.insert_resource(GameAssets {
        player: server.load("sprites/player.png"),
        music:  server.load("audio/theme.ogg"),
    });
}
```

- Handles are cheap to clone. Store them in a resource once at `Startup`.
- `Handle::Weak` is gone — use `Handle::Uuid` via the `uuid_handle!("…")` macro (was `weak_handle!`).
- Hot-reload: enable the `file_watcher` feature.
- Web assets (0.17+): add `http` / `https` / `web_asset_cache` feature and load URLs directly: `asset_server.load("https://…/image.png")`.
- `AssetLoader` / `Transformer` / `Saver` / `Process` impls require `TypePath` (0.18) — derive `TypePath` on your loader struct.

---

## 6. Best practices (idiomatic patterns)

1. **Group features into plugins.** Every feature is a `Plugin` that adds its own systems, resources, events, and state. `main()` becomes `App::new().add_plugins((DefaultPlugins, GamePlugin)).run()`.
2. **Name system sets with enum `SystemSet` derives,** not strings. Configure ordering in the plugin, then label systems with `.in_set(MySet::Logic)`.
3. **`FixedUpdate` for determinism.** Physics, gameplay logic, and anything that needs reproducible stepping go there. Rendering-adjacent interpolation lives in `Update`.
4. **Use observers for reactions, systems for polling.** "When X happens" → observer. "Every frame, check all X" → system with `Query<Added<X>>` or similar.
5. **`#[require(…)]` over `#[derive(Bundle)]`.** Bundles are legacy; required components make spawn sites clean.
6. **Auto-cleanup with `DespawnOnExit(State)`** instead of manual despawn lists.
7. **Store handles in resources.** Don't call `asset_server.load(...)` per frame.
8. **Use `.set_if_neq(new)`** for components/resources where you want to suppress spurious change-detection triggers.
9. **Prefer `Single<D, F>` over `Query::single()`** when a system logically needs exactly one match — the system is skipped if the invariant breaks, instead of panicking.
10. **Typed `Handle<T>`, not magic strings.** Reference assets through typed handles kept in a resource or a component field.

---

## 7. Common pitfalls

| Pitfall | Fix |
|---|---|
| Two `Query<&mut T>` in one system that could see the same entity | Wrap in `ParamSet<(Query<…>, Query<…>)>` and borrow one at a time |
| `commands.spawn(…)` then immediately querying in the same stage | Split into two systems ordered with `.chain()`, or use an `On<Add, C>` observer |
| `Query::single()` panicking at app start (no player yet) | Use `Single<D, F>` param, or `let Ok(x) = q.single() else { return; }` |
| Forgetting `add_message::<M>()` / `add_event::<E>()` | Register in the plugin's `build(&mut App)` |
| Mixing up `Event` (trigger + `On<E>`) and `Message` (writer/reader) | Pick one per type; only derive both if you truly need both roles |
| Polling `Interaction` every frame for UI clicks | Attach an observer: `.observe(\|_: On<Pointer<Click>>, …\| {})` |
| Using `Instant::now()` for timing | Use `Res<Time>` + `time.delta_secs()` — honors Bevy's time scaling & pausing |
| `&mut T` without actually changing value still trips `Changed<T>` | `.set_if_neq(new)` or compare-and-assign |
| Inserting/removing components in hot loops causes archetype churn | Toggle a field on the component, or use a `Disabled` marker |
| Stale `Entity` after despawn | `commands.get_entity(e).ok()?` / `q.get(e).ok()` before acting |
| Forgetting `#[reflect(Component)]` — type doesn't show up in scenes/inspector | Add it alongside `#[derive(Reflect)]` + `app.register_type::<T>()` (generic types still need explicit register) |
| Exclusive system (`&mut World`) blocking parallelism | Use sparingly; reach for `Commands` first |

---

## 8. Performance

- **`par_iter_mut()`** for large uniform workloads (~1000+ entities, roughly equal per-entity work). Bevy batches entity ranges across rayon workers.
- **`Has<T>`** instead of `Option<&T>` when you only need a boolean — archetype-friendly and branch-free.
- **Avoid archetype churn** (insert/remove) in hot paths. Toggle a field or keep a disabled-marker component added once.
- **Spawn in batches**: `commands.spawn_batch(iter_of_bundles)`.
- **Release profile tweaks** in `Cargo.toml`: `lto = "thin"`, `codegen-units = 1`, `panic = "abort"`.
- **Fast iteration** in dev: `dynamic_linking` feature (shared lib), `mold` or `lld` linker, optimize deps in dev (`[profile.dev.package."*"] opt-level = 2`).
- **Profile with Tracy**: enable `trace,trace_tracy` features; run Tracy profiler alongside for per-system timing.
- **Compile-time log filter** in release: set `log`'s `release_max_level_warn` feature so `debug!` / `trace!` calls compile out entirely.

---

## 9. Debugging & tooling

- **`bevy_dev_tools`** (cargo feature): FPS overlay (with frame-time graph in 0.17+), UI debug outlines, state visualizer.
- **`bevy-inspector-egui`** (third-party crate): live editor for resources/entities. Requires `Reflect` registrations.
- **Bevy Remote Protocol (BRP)** — enable `bevy_remote` and `bevy/remote` HTTP plugin:
  ```rust
  app.add_plugins((RemotePlugin::default(), RemoteHttpPlugin::default()));
  ```
  Exposes JSON-RPC methods `bevy/query`, `bevy/get`, `bevy/insert`, `bevy/spawn`, `bevy/list_components`. External tools (editors, MCP bridges like `bevy_brp_mcp`) use it.
- **Hot patching** (experimental, 0.17+): `subsecond` integration lets you patch systems at runtime without restarting. Binary crates only, not WASM.
- **Screenshot/recording** (0.18): `EasyScreenshotPlugin` (PrintScreen default), `EasyScreenRecordPlugin` (Spacebar; enable `screenrecording` feature).

---

## 10. Version migration — **read this before editing older code**

Version-specific changes Claude must apply when updating or translating code.

### 10.1 Bevy 0.17 → 0.18 (Jan 13, 2026)

**ECS**
| Old (0.17) | New (0.18) |
|---|---|
| `EntityRow`, `Entity::row()`, `Entity::from_row(...)` | `EntityIndex`, `Entity::index()`, `Entity::from_index(...)` (numeric still on `.index_u32()`) |
| `QueryEntityError::EntityDoesNotExist` | `QueryEntityError::NotSpawned` |
| `clear_children()` | `detach_all_children()` |
| `remove_children(&[e])` | `detach_children(&[e])` |
| `remove_child(e)` | `detach_child(e)` |
| `clear_related::<R>()` | `detach_all_related::<R>()` |
| `get_many_*` (on maps) | `get_disjoint_*` |
| `SimpleExecutor` | removed — use `SingleThreadedExecutor` / `MultiThreadedExecutor`, insert explicit `.before()` / `.chain()` where you relied on between-system flushes |
| `next_state.set(Same)` was a no-op | **always triggers `OnEnter`/`OnExit`**; use `set_if_neq` to restore no-op behavior |
| `EntityEvent` was mutable | **immutable by default**; `SetEntityEventTarget` trait for propagate-enabled events (auto-impl'd via `#[entity_event(propagate)]`) |
| `#[reflect[Clone]]` / `#[reflect{Clone}]` | only `#[reflect(Clone)]` |

New in 0.18:
- `EntityMut::get_components_mut::<(&mut A, &mut B)>()` — safe mutable multi-component access (runtime aliasing check).
- `app.remove_systems_in_set(MySet, ScheduleCleanupPolicy::…)` — actually remove systems from a schedule.
- System combinators (`.or`, `.and`, `.xor`, `.nand`, `.nor`, `.xnor`) now treat sub-system errors as `false` (were propagated).

**Rendering**
- `RenderTarget` is now a component: `commands.spawn((Camera3d::default(), RenderTarget::Image(h.into())))` — not a field inside `Camera`.
- `AmbientLight` resource → `GlobalAmbientLight`. `AmbientLight` is now a component to override per-camera.
- `Atmosphere` now takes `medium: Handle<ScatteringMedium>` and no longer `Default`s. Use `Atmosphere::earthlike(mediums.add(ScatteringMedium::default()))`.
- `Gizmos::cuboid` → `Gizmos::cube`.
- `MaterialPlugin { prepass_enabled: false, shadows_enabled: false }` → implement `Material::enable_prepass()` / `Material::enable_shadows()` methods on your `Material`.
- `TrackedRenderPass::set_index_buffer` dropped offset arg (offset via `BufferSlice`).

**UI / Text**
- `BorderRadius` moved onto `Node` (`node.border_radius = …`) — no longer a standalone component.
- `LineHeight` extracted from `TextFont` into its own component (required by `Text`, `Text2d`, `TextSpan`).
- `FontWeight` typed newtype; `FontFeatures` for OpenType.
- New widgets: `Popover`, `MenuPopup`, `ColorPlane`; new `AutoDirectionalNavigation`.

**Assets**
- Custom `AssetLoader` / `Transformer` / `Saver` / `Process` types must `#[derive(TypePath)]`.
- glTF: `GltfPlugin.use_model_forward_direction` → `GltfPlugin.convert_coordinates: GltfConvertCoordinates { rotate_scene_entity, rotate_meshes }`.
- `Mesh::*` methods gained `try_*` variants for meshes extracted to the render world; direct access may panic — prefer `try_attribute`, `try_compute_normals`, etc.

**Cargo features**
- New high-level: `2d`, `3d`, `ui` (grouped feature collections).
- `animation` → `gltf_animation`.
- `bevy_*_picking_backend` → `sprite_picking` / `ui_picking` / `mesh_picking`.
- Manual feature flags for input sources: `mouse`, `keyboard`, `gamepad`, `touch`, `gestures`.

**Animation**
- `AnimationTarget { id, player }` → `AnimationTargetId(id)` + `AnimatedBy(player_entity)`.

### 10.2 Bevy 0.16 → 0.17 (Sep 30, 2025)

**The headline**: the `Event`/`Message` split, observer rename, and renderer decoupling.

**Events & Observers**
| Old (0.16) | New (0.17) |
|---|---|
| `fn obs(t: Trigger<E>)` | `fn obs(e: On<E>)` |
| `#[derive(Event)] struct Foo;` + `world.send_event(Foo)` | `#[derive(Message)] struct Foo;` + `world.write_message(Foo)` (and `add_message::<Foo>()`) |
| `EventReader<Foo>` / `EventWriter<Foo>` | `MessageReader<Foo>` / `MessageWriter<Foo>` |
| Lifecycle observer `Trigger<OnAdd, C>` | `On<Add, C>` (short lifecycle names: `Add`, `Insert`, `Replace`, `Remove`, `Despawn`) |
| Entity-target events with manual propagation | `#[derive(EntityEvent)]` + optional `#[entity_event(propagate)]` |

Keep the old `Event` path for observer-style, one-shot triggers only; for anything that used to be a buffered event, switch to `Message`. `add_event::<E>()` still exists.

**ECS core**
- `Handle::Weak` / `weak_handle!("…")` → `Handle::Uuid` / `uuid_handle!("…")`. `clone_weak()` is now just `clone()`.
- `iter_entities()` deprecated — use `world.query::<EntityRef>().iter(&world)`.
- `Condition` trait → `SystemCondition`.
- `System::run(world)` now returns `Result`.
- `Option<Single<D, F>>` yields `None` on "multiple matches" (used to be `Err`).
- `Entity::from_raw(n)` → `Entity::new_bits(index, generation)` with `.index()` / `.generation()` accessors.
- `EntityClonerBuilder` split into `allow_component` / `deny_component` modes.
- `Bundle::register_required_components` removed — use `#[require(...)]` on the component.
- Observers and one-shot systems are tagged with an internal `Internal` component (filtered from default queries — use `Allow<Internal>` to include).
- System-set type names gained `Systems` suffix: `TransformSystem` → `TransformSystems`, `RenderSet` → `RenderSystems`, `UiSystem` → `UiSystems`, `PickSet` → `PickingSystems`, etc.
- State-scoped cleanup: `StateScoped(S)` → `DespawnOnExit(S)` / `DespawnOnEnter(S)`; `add_state_scoped_event` → `app.add_event::<E>().clear_events_on_exit(S)`.

**Renderer decoupling — imports moved out of `bevy_render`**
| 0.16 import | 0.17 import |
|---|---|
| `bevy::render::camera::Camera` | `bevy::camera::Camera` |
| `bevy::render::texture::Image` | `bevy::image::Image` |
| `bevy::render::mesh::Mesh` | `bevy::mesh::Mesh` |
| `bevy::render::render_resource::Shader` | `bevy::shader::Shader` |
| `bevy::render::light::PointLight` | `bevy::light::PointLight` |
| `bevy::core_pipeline::fxaa::FxaaPlugin` | `bevy::anti_alias::FxaaPlugin` |
| `bevy::core_pipeline::bloom::Bloom` | `bevy::post_process::Bloom` |
| `bevy::ui::render::UiMaterial` | `bevy::ui_render::UiMaterial` |
| `bevy::sprite::Material2d` | `bevy::sprite_render::Material2d` |

- `Camera { hdr: true }` field removed; spawn the `Hdr` component separately.
- Renderer resource init moved from `Plugin::finish` to a `RenderStartup` schedule: add systems with `render_app.add_systems(RenderStartup, init_my_resource)`.
- wgpu bumped to 25: custom shaders need `@group(#{MATERIAL_BIND_GROUP})` style bindings and typed shader constants.

**UI / Input**
- `CursorOptions` extracted from `Window` — query it separately.
- `BorderColor::all(c)` + per-side fields `top` / `right` / `bottom` / `left`.
- `ScrollPosition(Vec2)` newtype; computed position on `ComputedNode::scroll_position`.
- `JustifyText` → `Justify`.
- `Text2d` moved to `bevy_sprite`.
- Pointer events renamed: `Pointer<Pressed>` → `Pointer<Press>`, `Pointer<Released>` → `Pointer<Release>`.
- Picking and pointer input settings extracted into `PickingSettings` and `PointerInputSettings` resources.

**New features worth knowing**
- Headless UI widgets (Button, Slider, Scrollbar, Checkbox, RadioButton).
- Bevy Feathers (styled widget set, behind `experimental_bevy_feathers` feature).
- Bevy Solari (raytracing), DLSS.
- `Reflect` auto-registration across platforms (incl. WASM).
- Web assets (`http` / `https` features): `asset_server.load("https://…")`.
- Entity spawn ticks: `Query<Entity, Spawned>`, `Query<(Entity, SpawnDetails)>`.
- `children!` / `related!` macros support ~1400 children (was 12).
- `HierarchyPropagatePlugin::<C>` + `Propagate::<C>` / `PropagateStop::<C>` for downward component propagation.
- `ButtonInput<Key>` — layout-aware character input alongside `ButtonInput<KeyCode>` (physical).
- `Val` helpers: `px(8)`, `percent(50)`, `vw(10)`, `vh(5)` etc.
- `TemporalAntiAlias` is stable (no longer experimental prefix).

### 10.3 Bevy 0.15 → 0.16 (Apr 24, 2025)

**ECS**
- `Parent` → `ChildOf(Entity)` with `.parent()` method (no `Deref`).
- `.set_parent(p)` → `.insert(ChildOf(p))`.
- `despawn_recursive()` → **just `despawn()`** (children now cascade via relationships).
- `despawn_descendants()` → `despawn_related::<Children>()`.
- `Query::single()` / `single_mut()` now return `Result`; `get_single()` deprecated.
- `Query::many()` / `many_mut()` deprecated — use `get_many()` / `get_many_mut()`.
- Required component syntax refined: `#[require(A(returns_a))]` → `#[require(A = returns_a())]`; inline `#[require(A(10))]`.
- Relationships are first-class: `#[relationship]` / `#[relationship_target]` derives.
- Unified error handling: systems/observers/commands may return `Result<(), BevyError>`; `GLOBAL_ERROR_HANDLER` + `?` work across the board.
- Immutable components: `#[component(immutable)]`.
- Entity cloning: `clone_and_spawn`, `clone_components`, `move_components`, `EntityClonerBuilder`.
- Entity disabling: `Disabled` component, `register_disabling_component`, default query filters.
- `Event: Component` bound removed — add `#[derive(Component)]` explicitly if needed.
- `Resource` moved from `bevy::ecs::system::Resource` → `bevy::ecs::resource::Resource` (prelude unchanged).
- `track_change_detection` feature → `track_location`.
- `IntoSystemConfigs` → `IntoScheduleConfigs<ScheduleSystem, M>`.
- Rust 2024 edition required.

**Audio / rendering**
- `Volume(1.0)` → `Volume::Linear(1.0)` or `Volume::Decibels(0.0)`.
- GPU-driven rendering (multi-draw indirect, bindless) — automatic on Vulkan.
- Forward + clustered decals (`ForwardDecal`, `ClusteredDecal`).
- Anamorphic `Bloom { scale: Vec2 }`.
- `Atmosphere::EARTH` procedural atmosphere.

If you see `Parent`, `despawn_recursive`, `Volume(1.0)` as a scalar, `get_single`, or `SpriteBundle`/`NodeBundle` in user code, it's pre-0.16 — flag it and migrate the file as a whole rather than piecemeal.

---

## 11. Rules for Claude when writing Bevy code

1. **Default to Bevy 0.18.** Pin explicitly (`bevy = "0.18"`) when creating a new `Cargo.toml`.
2. **Observer parameter is `On<E>`**, not `Trigger<E>`. Lifecycle events are the short names: `Add`, `Insert`, `Remove`, `Replace`, `Despawn`.
3. **Distinguish Event vs Message.** Use `#[derive(Event)]` + `commands.trigger(..)` + `fn handler(ev: On<MyEvent>)`. Use `#[derive(Message)]` + `MessageWriter` / `MessageReader` for buffered fan-out. Register with `add_event::<E>()` or `add_message::<M>()`.
4. **Prefer required components over Bundles.** Write `#[require(...)]` on the primary component and spawn the primary component alone (or in a tuple to override). Don't introduce `*Bundle` structs unless explicitly asked.
5. **Hierarchy is `ChildOf` / `Children`**, and parent-despawn cascades — call plain `despawn()` (no `_recursive`). To detach in 0.18: `detach_child`, `detach_children`, `detach_all_children` (not `remove_*` / `clear_*`).
6. **State-scoped cleanup is `DespawnOnExit(S)` / `DespawnOnEnter(S)`.** Don't emit `StateScoped(...)` in new code.
7. **Return `AppExit`** from `main` when using `App::run()`.
8. **Use `Single<D, F>`** as a system param when exactly-one is required; use `query.single()` / `.single_mut()` returning `Result` otherwise — never `get_single()` in new code.
9. **Use `Val` helpers** (`px`, `percent`, `vw`, `vh`) for UI layout instead of constructing `Val` variants manually.
10. **Spawn `Camera3d::default()` / `Camera2d::default()`**, not `Camera3dBundle` / `Camera2dBundle`. Post-processing (`Hdr`, `Bloom`, `Tonemapping`, `Fxaa`, `TemporalAntiAlias`) are components you add to the camera entity. `RenderTarget` is a component in 0.18.
11. **`Res<Time>` + `time.delta_secs()`** for all time-based math. Physics / deterministic logic in `FixedUpdate`.
12. **Use observers for UI interactions**: `button_entity.observe(|_: On<Pointer<Click>>, ...| {})` — not `Query<&Interaction>` polling.
13. **Group feature code into `Plugin`s.** A new subsystem means a new `impl Plugin for MyPlugin { fn build(&self, app: &mut App) { ... } }`.
14. **Store asset handles in resources** loaded at `Startup`. Don't re-`load()` per frame.
15. **Register reflection** when serializing to scenes or exposing to BRP / inspector: `#[derive(Reflect)] #[reflect(Component)]` (or `#[reflect(Resource)]`), plus `app.register_type::<T>()` only for generic instantiations.
16. **Don't panic in library code.** Return `Result<(), BevyError>` and use `?`; for queries, use `Single` or `get_*` methods.
17. **When editing an older project**, detect the Bevy version from `Cargo.toml` first:
    - 0.15: flag and suggest migration
    - 0.16: use `Trigger<E>`, `Event`-only, pre-decoupled imports
    - 0.17: use `On<E>`, `Event`/`Message` split, post-decoupled imports
    - 0.18: everything in this skill is current
   Match the project's version when editing; only migrate when the user asks.
18. **Never introduce `--no-verify`, silent `unwrap()` on `Query::single()`, or disabled warnings** to paper over issues the migration tables above already solve.

---

## 12. Useful references (don't over-fetch — these URLs can drift)

- Release blogs: `https://bevy.org/news/bevy-0-18/`, `/bevy-0-17/`, `/bevy-0-16/`
- Migration guides: `https://bevy.org/learn/migration-guides/0-17-to-0-18/`, `/0-16-to-0-17/`, `/0-15-to-0-16/`
- API docs: `https://docs.rs/bevy/0.18` (swap version in the URL as needed)
- Official examples: `https://github.com/bevyengine/bevy/tree/main/examples` — `ecs/`, `ui/`, `3d/`, `2d/`, `animation/`, `shader/` subdirs are the canonical reference implementations
- Cheatbook (unofficial, useful for concepts but often lags a version): `https://bevy-cheatbook.github.io/`
