# JSON:API Kit — implementation plan

**Status:** working document for the production implementation (branch `loic/json-api-kit-core`,
started 2026-08-03). The spike lives on `loic/json-api-experiments` — proven behaviour, spike-shaped
code, and the reference docs that explain *why* each decision was made. This plan says how we get
from one to the other.

## The bar

This is the real thing, so the spike's licence to take shortcuts is withdrawn:

- **Generic, not "enough for our first endpoint".** Every case the JSON:API spec describes will exist
  eventually; the design must not foreclose one. Where we don't implement something yet, it is
  because of sequencing, and the shape has to leave room for it.
- **Concepts identified and encapsulated.** Small objects, each with one job, named after what it *is*
  in the domain. The spike's 623-line `BaseController` is the anti-pattern: it resolved versions,
  parsed six parameter families, filtered, sorted, paginated, deserialized, rendered and built errors.
  All of those are separate concepts.
- **Specs first, always.** Behaviour is pinned before it is written; the spike's acceptance specs are
  the checklist we port.
- **No stand-ins.** No `serializer_for` placeholder registry, no monkeypatch from a plugin, no
  hand-maintained endpoint maps.

## Settled

| Question | Decision |
| --- | --- |
| URL | `/api/...` (easy to change later) |
| Namespace | `JsonApiKit` — that's the name now |
| Home | `lib/json_api_kit/` — a self-contained layer, extractable to a gem if it ever needs to be |
| Resources | `app/resources/`, with an `ApplicationResource` in the app, mirroring the `ApplicationRecord`/`ApplicationController` convention |
| Controllers | `JsonApiKit::BaseController` in the lib; the app subclasses through its own base |
| First endpoint | Its own slice, after the framework core — the framework is driven by specs first |
| `from_resource` | Slice 4, with the writes |
| Developer guide | Later, once the shape is real |

## Slices

Each is independently reviewable and additive — nothing existing changes behaviour, and nothing is
routed until we route it.

1. **Framework core.** Declarations, request parsing, query building, pagination, document assembly,
   errors. Driven entirely by specs (see *Testing without an endpoint*). This is the "core of the
   framework with missing stuff" that merges first.
2. **First endpoint.** A real resource on `/api/...`, which turns the framework's unit-proven parts
   into an end-to-end path.
3. **Versioning.** Registry, `VersionChange`, gap resolution, up/down pipeline, header handling.
4. **Writes.** `POST`/`PATCH`, the service bridge, `422` with JSON Pointers, `from_resource`.
5. **Documentation generation.** OpenAPI document, committed artifacts, drift loop.
6. **Contract guard.** Committed descriptor, CI failure on incompatible change.
7. **API key scopes.** Derived per endpoint, plugged into the existing system.
8. **Publication.** `internal`, the route helper's prefix derivation.
9. **Plugin extension API.** Namespaced relationships, filters, own timelines.
10. **Endpoint lifecycle.** Deprecation, dated removal, usage metering.

## Object map for slice 1

Names are the point of this section: each of these is a concept the spike had, mostly tangled inside
the controller. Every one of them should be testable without a request.

**Declarations** (`app/resources`, `lib/json_api_kit/declarations/`)

- `Resource` — the base class; declarations only, no behaviour beyond recording them.
- `Attribute`, `Relationship`, `Filter`, `Sort`, `Anchor`, `PageLimits`, `IncludePaths` — one object
  per declared concept, each owning what it knows: an `Attribute` reads a value off a record, a
  `Filter` applies itself to a scope, a `Sort` says whether it is column-derived, SQL-backed or opaque
  and yields its keyset key, an `Anchor` selects a row.
- `ResourceRegistry` — type ⇄ resource, replacing the spike's stand-in.

**Request** (`lib/json_api_kit/request/`) — one object per reserved parameter family, each strict by
construction, so "unknown parameter → 400" is not a separate concern:

- `Request::Fields`, `Request::Include`, `Request::Filters`, `Request::Sort`, `Request::Page`,
  `Request::Version`, `Request::Document` (writes).
- Each returns a value object: `Fieldsets`, `IncludePaths`, `AppliedFilters`, `Keyset`, `PageRequest`,
  `VersionPin`, `WriteDocument`.

**Pagination** (`lib/json_api_kit/pagination/`)

- `Keyset` — keys, directions, SQL-backed expressions, joins, nullable keys; knows how to project
  itself onto a scope.
- `Cursor` — value ⇄ opaque string, with shape validation. Owns the lesson that lossy encoding breaks
  keysets (timestamps at full precision).
- `Window` — records plus whether more exist either side.
- `Paginator` — scope + keyset + request → `Window`.
- `Anchor::Resolver` and `Anchor::Window` — positional entry, including the centred form.
- `Profile` — the cursor-pagination profile's names, error type URIs and content type in one place.

**Documents** (`lib/json_api_kit/documents/`)

- `Collection`, `Resource`, `Errors` — assembly, each aware only of its own shape.
- `Links`, `ItemMeta`.
- `Errors::*` — one object per typed error (unsupported sort, max size exceeded, invalid cursor,
  unknown parameter, range pagination), each knowing its status, title, type URI and source pointer.

**Endpoint** (`lib/json_api_kit/`)

- `Endpoint` — the controller's declarations (resource, services, publication, scope overrides),
  extracted so the controller carries no state of its own.
- `Endpoint::Index`, `Endpoint::Show` — orchestrate scope → filters → keyset → window → document.
- `BaseController` — thin: builds a request context, delegates, renders. If it grows past a screen,
  something above is missing.

## Testing without an endpoint

Slice 1 has no real endpoint by design, and that is a feature: it forces the framework to depend on
nothing in the app.

- **Unit specs per object.** Most are pure; the ones touching the database take a scope.
- **Framework request specs against a fixture endpoint** defined in spec support (a `Resource` over an
  existing model plus a controller), with routes drawn per example. `with_routing` is the intended
  mechanism — to be confirmed, as nothing in the repo uses it yet; the fallback is a test-only route
  file loaded in the test environment.
- **Ported acceptance specs as the checklist**: profile conformance, traces A–G (slice 3), plugin
  rules (slice 9), documentation drift (slice 5), scopes (slice 7), anchors and centred windows,
  publication (slice 8).

## Ported, rewritten, decided

- **Ported nearly as-is** (proven, and the knowledge is in the details): the keyset predicate work
  including the null-safe equality, cursor encoding, nulls-last projection, the version pipeline's key
  maps and gap ordering, the OpenAPI schema derivation.
- **Rewritten**: everything that lived in the controller, the config object (the resource *is* the
  config), the endpoint registry, the plugin registration surface (it belongs in core's plugin API,
  not monkeypatched from a plugin).
- **Dropped**: `stats[total]=count` (not in the profile, unbounded count), the run-stats stand-in
  plugin, the endpoint map.

### Open decision: the renderer

The spike renders with **jsonapi-serializer 2.2.0** plus an owned one-line monkeypatch: the gem builds
each nested resource's hash with the *parent's* parsed include list, so with `lazy_load_data` a nested
leaf's linkage disappears — a full-linkage violation. The gem is feature-dead.

Three options:

1. **Keep it, keep the patch.** Cheapest, measured fastest of the three renderers we benchmarked, but
   we own a patch on a dormant gem and we will hit its other gaps (relationship `links`, which
   WarpDrive's relationship mode wants, are not emitted at all).
2. **Vendor it** (~500 lines, MIT) and maintain it as ours.
3. **Write the document assembler.** It is not large — resource objects, `included` deduplication,
   sparse fieldsets, linkage, meta and links — and we already isolate it behind our own declarations,
   so the blast radius is internal. It removes a dependency, a patch, and the ceiling on spec
   coverage.

Recommendation: build option 3 behind the existing port during slice 1 and **benchmark it against the
gem on the same data** (the harness exists). Keep the gem only if ours is materially slower. Three
strikes — a patch, dormancy, and missing relationship links — argue for owning it.

## Definition of done, per slice

- Specs green, lint clean, no TODOs left in the code.
- Every JSON:API area the slice touches is either covered or explicitly listed as sequenced-not-built,
  in this document.
- Reference material updated when a decision changes — the durable artifact is the design, not the
  code.
