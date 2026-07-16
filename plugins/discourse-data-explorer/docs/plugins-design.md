# JSON:API Kit — Plugins Design

**Status:** design settled in pairing sessions (2026-07-15/16); nothing built. Per-owner
resolution needs a second registered owner to be testable, and data-explorer is the spike's
only one — implementation belongs to the real Kit phase.
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
without the plugin. Registration sketch (final API TBD):

```ruby
# core type → plugin-owned type; include-gated. The relationship is named by the
# plugin's namespace (see D) — one word for include name and query-key prefix.
register_jsonapi_relationship(:topics, serializer: WidgetStatusSerializer)
# plugin-owned types only (A enforced here)
register_jsonapi_version_change(RenameWidgetStatusStateToPhase)
```

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

**Design (retained): one clock — core's — plus explicit per-plugin overrides.**

- A deployment advertises **core's cut** as *the* API version. In-core plugins share core's
  clock by construction (same repo, same cut).
- **Resolution:**
  1. **Parse.** Base date required (else the teaching 400). Optional `component=date`
     overrides — strawman syntax `Api-Version: 2026-01-31; some-plugin=2026-07-15`, exact
     format TBD. Any calendar-future date → 400. An override naming an unknown component →
     400. An override naming an *in-core* plugin → 400: the release is one contract, no
     skew within it (relaxable later; hard to un-relax).
  2. **Ceiling the base at core's cut:** `effective_base = min(requested, core_cut)`. The
     load-bearing line — no stored pin can sit past the cut where the next release's core
     changes will appear, so failure narrative (1) becomes impossible by construction.
  3. **Snap each date against the change-set it governs:** the base snaps down against the
     union of changes from all non-overridden owners; each override snaps against that one
     plugin's own changes. One rule, applied per date.
  4. **Echo the fully-resolved string;** clients store it verbatim. Never-flip holds per
     component: each echoed date is ≤ the newest change that component had shipped when it
     was echoed, and later deploys only add changes dated after it.
- **Default = frozen at pin.** A non-overridden out-of-tree plugin's changes dated after
  the pin are down-applied exactly like core's: pinned clients keep the old shapes, stable
  by default. Additive plugin changes are not version-gated and flow through regardless —
  overrides only matter for *breaking* changes to plugin-owned types mid-cycle.
- **Override = deliberate unfreeze,** one named plugin at a time. The consumer updates its
  pin in the same change that adopts the new shapes — honest lockstep, no silent contract
  shifts. This is deliberately *better* than the automatic variant it replaced, not merely
  cheaper.
- Echoing the **snapped** date rather than the ceiling is deliberate: the snapped date is
  the oldest safe representative of the requested contract, which also shrinks the residual
  below.
- In-core vs out-of-tree is mechanically detectable (the plugin directory belongs to core's
  git worktree vs being its own clone) — no self-declared metadata that can lie.
  Implementation note for the real phase.

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
- **One namespace per plugin**, declared once at registration, globally unique — boot
  error on collision, including against member names already present on the core types it
  attaches to. The namespace **is** the B relationship name: one word serves as the
  include name, the filter prefix, and the sort prefix.
- **The framework namespaces automatically.** Plugins register *local* keys and never
  write their own prefix:

  ```ruby
  register_jsonapi_filter(:topics, :state) { |scope, value| … }  # wire: filter[solved-status.state]
  register_jsonapi_sort(:topics, :answered_at) { |scope, dir| … } # wire: sort=solved-status.answered_at
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
