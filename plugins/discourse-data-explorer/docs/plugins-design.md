# JSON:API Kit — Plugins Design

**Status:** design settled in pairing sessions (2026-07-15/16) and **proven in the spike**
via a fake extension registered at spec time
(`spec/requests/discourse_data_explorer/json_api_kit/plugin_extensions_spec.rb`): ownership
enforcement (A), include-gated relationships (B), per-owner version changes with
auto-namespaced filter renames (D), disabled-plugin strictness (E), and the C resolution —
core-timeline base snap, per-plugin overrides, per-owner gaps, and `CORE_PLUGINS`-granted
core-timeline membership (bundled plugin's change advances the advertised version; its
override → 400). Still unbuilt: the plugin-facing `jsonapi` block in plugin.rb (the spike
registers at the Kit level), `register_sort` projection, date-monotonicity enforcement,
the repo ⟺ `CORE_PLUGINS` CI consistency check, F (frontend).
**References:** [versioning design](./versioning-design.md) (the machinery all of this composes with) · [Stripe versioning](./stripe-api-versioning-reference.md) · [JSON:API spec notes](./jsonapi-spec-reference.md).

---

How plugins participate in the versioned JSON:API. Designed against the deployment
configurations that actually exist:

1. **Frequently-deployed hosting** — core and plugins both move ~continuously; any gap
   between their timelines stays small.
2. **Monthly/ESR releases** — everything frozen for one/six months, then a jump. Verified:
   official plugins ship inside the core repository, and standard hosting tiers run only
   those (per-tier availability is toggled through site settings, not extra plugin installs) —
   so these sites are *one repo, one cut, one clock*. No cross-component skew exists here.
3. **Sites additionally running custom or third-party plugins**, deployed from their own
   repositories on their own cadence — e.g. a site pinned to a release for stability while a
   custom plugin it runs is actively developed. The only configuration where core and plugin
   timelines genuinely diverge, and the one the timeline design (C) exists for.

## A. Ownership: plugins own their types

A plugin registers version changes only for resource types it owns; core types are never
mutated by plugin changes (and vice versa). Since all the machinery is already type-keyed —
transforms, fieldset maps, error-pointer rewrites, sort/filter renames — registries compose
by simple merge and two owners can never collide on a type. Enforced at registration:
registering a change against a type you don't own is an error.

## B. Placement: plugin data hangs off core types as relationships

Plugin data on a core resource is exposed as a **relationship** from the core type to a
plugin-owned type — never as extra attributes injected into the core type. Injected
attributes would make a core type's contract depend on the installed plugin set; a
relationship to a plugin-owned type keeps every contract owned by exactly one party, and is
include-gated (absent unless requested), so core documents are byte-identical with or
without the plugin. Registration happens in a single `jsonapi` block in plugin.rb — the
plugin's whole wire contract, reviewable as a unit and one grep away (final API TBD):

```ruby
jsonapi namespace: "solved-status" do
  # core type → plugin-owned type; include-gated. The relationship is named by the
  # namespace (see D) — one word for include name and query-key prefix.
  register_relationship :topics, serializer: SolvedStatusSerializer
  # plugin-owned types only (A enforced here)
  register_version_change RenameSolvedStatusStateToPhase
end
```

The block form is deliberate, for three mechanical reasons. It registers **atomically**:
the whole contribution is validated as a unit when the block closes (namespace uniqueness,
collisions against core member names, changes targeting only owned types) — no ordering
bugs between loose calls. It is **lazily evaluable**: plugin.rb runs at boot before
autoloading is ready (the spike hit exactly this), so the Kit stores the block and
evaluates it once serializer and change classes are loadable, instead of every plugin
author rediscovering the boot-ordering problem. And the **namespace closes over every
helper inside**: nothing can be registered without one, and no helper ever takes a prefix
argument (see D's auto-namespacing). The `register_` verb is kept on the helpers because it
marks "attaching to someone else's surface" — distinguishing this DSL from the *resource*
resource class, where bare declarations (`filter`, `sort`, …) describe the plugin's own
endpoints. Scope discipline: a plugin's own resources keep their declarations in the
plugin's resource/controller classes, exactly like core's; the plugin.rb block holds only
the extension surface (attachments to foreign types) and the plugin's version timeline.

Contract guards run per owner: a plugin's schema baseline covers its own types plus the
relationships it registers, so a breaking change on either fires that plugin's guard, not
core's.

## C. The version timeline with plugins

The question: a deployment is core + N plugins — N+1 independently-advancing change
timelines. What does one `Api-Version` date mean against that?

**Failure narratives that shaped the design** (each broke a previous iteration; kept
because they are the argument for the final shape):

1. *Union timeline, advertise the max.* Merge every component's changes into one timeline
   and advertise the newest date across core + plugins. **Break:** on a release-pinned site
   (cut = Jan 31), a plugin updated in March pushes the advertised version to March; a
   client integrating then pins March; the next release ships core changes dated Feb–Jun,
   and the ones dated ≤ March are *not* down-applied for that pin — the pinned client sees
   new core shapes it never coded against. Advertising the union max lets one component's
   movement strand pins past another component's future changes.
2. *Clamp everything — advertising and resolution — to the oldest component cut.* Fixes (1)
   by construction, but on a site whose custom plugin is deliberately advancing while core
   stays pinned (configuration 3 above), the plugin's new shapes become unreachable until
   the next core release — unacceptable for exactly the consumers that plugin is advancing
   for.
3. *Automatic per-component resolution* (the server clamps each component to that
   component's own cut and echoes an expanded per-component pin). Rejected on inspection:
   an out-of-tree plugin deployed from its repository HEAD has no natural "cut", so the
   general mechanism degenerates into a two-class rule anyway — and auto-resolving a plugin
   at latest means a pinned client's contract silently shifts every time that plugin ships
   a breaking change, which is the precise surprise versioning exists to prevent. Every
   client would also pay the expanded-echo complexity to serve a small expert population.
4. *Uniform plugins — every plugin on its own timeline, base snap = core-only.* (Briefly
   built.) **Break:** on a frequently-deployed branch, a bundled plugin ships a breaking
   change on its own types and updates every caller in the same commit — yet the change is
   unreachable: the base date snaps to *core's* newest change, so every base-date client
   (including the first-party frontend, which ships in lockstep and wants exactly this
   change) gets the old shape down-applied. The escape is one override per bundled plugin —
   dozens of machine-generated dates in the header for "just give me this deployment's
   API". Treating plugins uniformly conflated two orthogonal properties; the fix is to
   separate them (below).

**Design (retained): one clock — core's — plus explicit per-plugin overrides.**
*(Simplified 2026-07-16, then built in the spike. Two ideas from the first draft died on
inspection: the "core cut" concept proved mathematically redundant, and the in-core vs
out-of-tree plugin classification proved unnecessary — see below.)*

- **The base snap set is core's timeline only.** ("Core" throughout = the API's owner, who
  registers changes directly into the registry — Discourse core in the real phase; in the
  spike, data-explorer's Kit plays that role.) The newest core-owned change *is* the
  deployment's knowledge of its own edge — the deployed registry cannot contain what hasn't
  shipped — so no release-cut metadata exists anywhere. Equivalence note: the first draft
  ceilinged the base at the release cut and then snapped; since every deployed core change
  is dated ≤ its cut, `snap(min(requested, cut))` = `snap(requested)` for every input. The
  snap-down mechanism already built *is* the ceiling, and failure narrative (1) stays
  impossible by construction: a resolved base can never sit past core's newest shipped
  change.
- **Vocabulary ownership and timeline membership are orthogonal.** Ownership (types,
  namespaces, transforms, filter-rename projections) is per-plugin, always — A/B/D
  unchanged. Timeline membership is a **shipping property**: the question is never "is
  this plugin core?" but "does this code deploy atomically with core?". An extension
  that ships with core (one repo, one deploy — the bundled plugins) **rides the core
  timeline**: its change dates join the base snap set, so a bundled plugin's breaking
  change advances the advertised version and "send today" reaches it — and it cannot be
  overridden (the train is one contract). An independently-shipped extension keeps its own
  timeline: frozen at pin by default, reached through overrides.
- **Membership is granted by core, never claimed by the plugin.** A `CORE_PLUGINS`
  allowlist in core's codebase (reviewed data — the `config/official_plugins.json`
  precedent) decides; the plugin-facing DSL has *no syntax* for it, the same
  inexpressibility trick as auto-namespacing. Fails closed: a forgotten entry puts a new
  bundled plugin on its own timeline — override-gated and visible, never a stranded pin.
  The dangerous drift is the *stale* entry (a plugin extracted from the repo but still
  listed re-creates failure narrative 1), so the real-phase companion is a CI consistency
  check: plugins in the core repo ⟺ names in the list, both directions. Runtime never
  trusts repo layout; CI checks it where git reliably exists.
- **Resolution** (as built):
  1. **Parse** `Api-Version: 2026-06-01; some-plugin=2026-06-25` — base date required (else
     the teaching 400), overrides optional. Any calendar-future date → 400; an override
     naming an unknown or uninstalled extension → 400.
  2. **Snap each date against the timeline it governs:** the base against core's
     changes; each override against that extension's own changes (both anchored on the
     same initial version). One rule, applied per date.
  3. **The gap is the union** of all owners' changes, each governed by its owner's
     effective date — the override where one was named, the base otherwise.
  4. **Echo the fully-resolved string** (`2026-05-01; some-plugin=2026-06-20`); clients
     store it verbatim. Never-flip holds per owner.
- **Default = frozen at pin.** A non-overridden extension's changes dated after the
  resolved base are down-applied exactly like core's: pinned clients keep the old
  shapes, stable by default. Additive plugin changes are not version-gated and flow through
  regardless — overrides only matter for *breaking* changes to plugin-owned types.
- **Override = deliberate unfreeze,** one named plugin at a time. The consumer updates its
  pin in the same change that adopts the new shapes — honest lockstep, no silent contract
  shifts. This is deliberately *better* than the automatic variant it replaced, not merely
  cheaper.
- **The date-monotonicity invariant is now load-bearing.** Never-flip rests on: within one
  owner's timeline, a new change is never dated before an already-shipped one (no
  backdating). This was implicit under the cut model; with the cut gone it is the single
  pillar, and it is cheaply enforceable — the registry (or CI) rejects a new change dated
  before its owner's newest registered one. Enforcement not yet built.
- Two consequences, stated honestly:
  - **Extension dates never appear in base echoes** — a base pin always reads against one
    public changelog; plugin timelines surface only in override echoes.
  - **A quiet core timeline delays plugin-latest for base-date clients — own-timeline
    extensions only.** If the core timeline ships no breaking change for months, an
    independently-shipped extension's new shapes stay override-gated for that period (the
    base cannot snap past the core timeline's last change). Consistent — the train is the
    clock, and own-timeline consumers are the override-capable population — but
    documented, not silent. Bundled plugins are unaffected: they *are* the train. The
    client rule for the official docs, said loudly: *send today's date, store the echo;
    add `plugin=today` for any independently-shipped plugin whose latest shapes you need.*

**Residual, documented not solved:** a stale third-party plugin that sits unupgraded for a
long time and then jumps to its repository HEAD can introduce changes dated *before*
existing pins — those won't be down-applied for such pins. Contingency if it ever bites:
effective change date = max(authored date, first seen on this site). Unbuilt.

## D. Query-surface extension: namespaced and additive-only (decided 2026-07-16)

The need, real today: filters/sorts on **core** listings driven by plugin data ("list
unsolved topics"). The filter key lives on core's surface while the behavior belongs to the
plugin — the case that looked like it strained rule A. Decisions:

- **Additive only.** A plugin never modifies core's existing filters or sorts, and never
  changes a core type's `default_sort` — it only adds new keys. This is B's placement
  rule applied to the query surface: share by adding your own vocabulary, never by mutating
  someone else's.
- **One namespace per plugin**, declared at its `jsonapi` block boundary (see B), globally
  unique — boot error on collision, including against member names already present on the
  core types it attaches to. The namespace **is** the B relationship name: one word serves
  as the include name, the filter prefix, and the sort prefix.
- **The framework namespaces automatically.** Inside its `jsonapi` block, a plugin
  registers *local* keys and never writes its own prefix:

  ```ruby
  register_filter(:topics, :state) { |scope, value| … }  # wire: filter[solved-status.state]
  register_sort(:topics, :answered_at) { |scope, dir| … } # wire: sort=solved-status.answered_at
  ```

  A foreign key is thereby *inexpressible*, not merely forbidden — ownership holds by
  construction, no validation needed. Core keys stay un-namespaced, so shadowing a core
  key is equally impossible.
- **One attachment point per core type.** JSON:API forbids `.` in member names, so the
  namespace-as-relationship-name rule means a plugin attaches to a given core type through
  exactly one relationship; richer plugin data hangs off the plugin's own type graph,
  reachable through include paths (`include=solved-status.answer`). Dotted query keys then
  read as paths through that single relationship — the *existing* relationship-path
  convention (`sort=user.username`), not new syntax. Predicate-style keys that aren't
  literal attribute paths (`solved-status.unsolved`) stay legal: filter semantics are
  server-defined.
- **Ownership amendment to A:** document vocabulary is owned by *type*; query-surface
  vocabulary is owned by *namespace*. A plugin's `VersionChange` may declare
  `renamed_sort`/`renamed_filter` for keys under its own namespace even though the surface
  belongs to a core type — and the framework namespaces both sides of the rename, so
  foreign renames are inexpressible too. Rename maps merge per type across owners;
  disjoint namespaces cannot collide (same argument as disjoint types).
- **Registration targets the type, not a controller.** A registered filter works on every
  listing where that type is primary — consistent with the per-resource query-surface
  position ([versioning design §3](./versioning-design.md)) and with the follow-up of
  moving query declarations to a resource-level home.
- **The namespace is immutable** for now: changing it would be a coordinated breaking
  change across the relationship name and every query key. A `renamed_namespace` keyword
  is conceivable; not sketched until a real need shows up.

Mechanically this is nearly free: the DSL already builds a name-keyed config map of
filter/sort entries, registration merges into it, strict-params allowlisting and dispatch
(`block.call(scope, value)`) are unchanged. Notes: registration mirrors B's
guardian-gating option; plugin *sorts* inherit the virtual-sort limitation (they order
fine but cursor pagination answers the typed unsupported-sort error until the
virtual-column keyset pattern from core PR #36065 lands); a disabled plugin's keys vanish
→ strict 400 (see E).

## E. Smaller positions

- **Plugin disabled/uninstalled:** its types, includes, and query keys vanish → strict
  400s. Disabling a plugin is a site-admin breaking act, out of versioning's scope (Stripe
  can't version "we turned the product off" either) — stated here so nobody expects
  transforms to cover it.
- **Conditional plugin data:** guardian-gated relationships — already expressible at the
  serializer level, no new mechanism.
- **Same-date ordering across owners:** registration order = plugin load order,
  deterministic per site — and irrelevant in practice, since disjoint owners (types and
  namespaces) never contend.

## F. Frontend consumption (WarpDrive — target-state sketch, verified 2026-07-16)

Context: the frontend is migrating its models from the home-grown `RestModel` layer to
[WarpDrive](https://warp-drive.io) as a separate project — deliberately
**decoupled** from the backend JSON:API work, consuming the *current* API through a custom
adapter first. This section is the *target state* once both tracks land, verified against
the WarpDrive docs (v5.8.2); the specifics below should be aligned with the migration
project as its code lands, not decided unilaterally here.

- **Two-phase convergence, cheap by architecture.** WarpDrive isolates API shape in two
  places — request builders and the handler chain. Moving from "current API via custom
  adapter" to the Kit's JSON:API swaps those for the stock `@warp-drive/json-api` cache and
  `@warp-drive/utilities/json-api` builders; the store, schemas, reactivity, and component
  call sites stay put.
- **Includes — the D counterpart.** Builders are pure functions taking include arrays
  (`query('topics', { include: [...] })`) and normalize param order into stable cache URLs.
  Core exposes an include registry per type and merges it when building listing requests; a
  plugin opts its namespace in (sketch: `api.registerJsonApiInclude("topics",
  "solved-status")`). Opt-in per surface, not automatic — includes cost payload, so the
  plugin must *say* it wants its relationship on a listing.
- **Version header — one seam.** A single app-wide handler in the RequestManager chain
  stamps `Api-Version` on the way out (`next({ ...context.request, headers })`) and reads
  the echo on the way back (`result.response.headers`). The first-party frontend ships in
  lockstep with the backend, so it is an *always-latest* client sending the deployment's
  advertised version — the pin/snap/override machinery (C) exists for external
  integrations, not for our own app.
- **Schema — the B counterpart, and a verified constraint.** WarpDrive has **no
  third-party schema amendment**: traits must be opted into by the schema's owner, and
  extensions add behavior only (explicitly framed as migration escape hatches). A plugin
  therefore cannot bolt its relationship onto core's `topic` schema after registration —
  core must collect plugin field definitions *before* calling `registerResource`, the same
  composition-point pattern as the backend registration API. Better: the backend already
  knows the complete schema from the B registrations, and `SchemaService` explicitly
  supports registering schema "delivered by API calls or other sources just-in-time" — so
  the frontend schema can be **derived server-side and delivered to the client**, making
  the Ruby registration the single source of truth (the plugin's frontend declares no
  schema at all). Open sub-question: delivery via the bootstrap preload vs a dedicated
  endpoint.
- **Access and rendering.** Resources in `included` auto-normalize into the cache and
  relationship fields surface as reactive properties: a topic-list connector reads
  `topic.solvedStatus.state` where today it reads an attribute inlined into core's payload
  by the plugin. The rendering machinery (plugin outlets, value transformers) is untouched;
  only the data path changes.
- **Caveat, stated plainly:** relationship support in Polaris mode (WarpDrive's modern API)
  is *preview* — relationships must be `async: false` with `linksMode: true`, which requires
  a `related` link in the payload, and stabilization is slated for WarpDrive V6. Two
  consequences: the Kit should emit `links.related` on relationships (JSON:API-idiomatic
  regardless), and the frontend timeline has a real dependency on WarpDrive's roadmap.
