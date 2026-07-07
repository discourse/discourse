# Ruby Versioning Gems — Evaluation for the JSON:API Kit

**Evaluated:** 2026-07-07 · **Candidates:** [`request_migrations`](https://github.com/keygen-sh/request_migrations) (keygen-sh), [`gates`](https://github.com/phillbaker/gates) (phillbaker)

**Question:** do either of these give us the *transform layer* for the JSON:API Kit's date-based versioning
("System A" in the [Cadwyn review](./cadwyn-review.md) — a pipeline of reversible transforms over
request/response hashes), so we can adopt rather than build? Judged against our concrete needs: a mandatory
`Discourse-Api-Version: YYYY-MM-DD` header, an always-latest internal representation, transforms that migrate
DOWN (response) and UP (request) over jsonapi-serializer documents + inbound params, writes via `Service::Base`,
and a **plugin-extensible** transform registry.

Companion reference: [Stripe versioning](./stripe-api-versioning-reference.md) · [Cadwyn review](./cadwyn-review.md).

---

## TL;DR — recommendation

**Own the design, don't take the dependency.** Neither gem is adoptable as-is, but for opposite reasons:

- **`gates` — skip.** Dead since 2016, and the *wrong model*: a version→boolean feature-flag lookup, not a
  transform pipeline (zero payload rewriting). Borrow exactly one idea (versions as a predecessor chain +
  id→version registry); model nothing else on it.
- **`request_migrations` — the reference design, but own it.** Conceptually a bull's-eye (always-latest +
  bidirectional up/down migrations, first-class `:date` versions, header-driven resolution) and — critically —
  **clean** (no ActiveRecord/core monkeypatching; verified). But it's ~546 LOC, dormant/single-maintainer with
  weak CI, and **missing exactly our two hard requirements**: JSON:API-document ergonomics and a plugin-extensible
  registry. Depending on it buys little while inheriting a quiet upstream we'd have to extend anyway.

So: **lift its architecture into the Kit** (the `Migration` DSL, the directional `Migrator`, the header resolver,
the date `Version`) and add the two pieces it lacks. This is the same "own a small, ownable, lock-in-free layer"
call the team already made choosing the Kit over Graphiti — and 546 LOC is comfortably inside "ownable."
(If we want to move fast initially, depending on `1.1.2` as a *temporary bridge* is low-risk — its integration
surface is tiny, so later extraction is painless. But the end state is own-it.)

This is a recommendation, not a decision — the build-vs-bridge call is the team's.

---

## At a glance

| | `request_migrations` | `gates` |
|---|---|---|
| **License** | MIT (Keygen LLC) | MIT |
| **Latest release** | `1.1.2`, 2025-11-04 — but a compat one-liner after a **~3.25-yr gap** (1.1.1 = 2022) | `0.0.1`, 2016-10-30 (only release ever) |
| **Activity** | Effectively dormant; single maintainer (`ezekg`); production-proven at Keygen | **Dead** — 2 commits total, both Oct 2016; 0 forks/issues |
| **CI** | Ruby 3.2.2 only, no Rails matrix (Rails 8 / Ruby 3.4 not proven, but nothing blocks; runs on 3.4.7) | Ruby 2.1–2.3 era; `Gates.load` is broken on every Ruby |
| **Size** | ~546 LOC / 9 files — trivially forkable | ~83 LOC — nothing to own |
| **Model** | Stripe-style always-latest + reversible up/down **transforms** | version→boolean **feature-flag lookup** (no transforms) |
| **Core monkeypatching?** | **None** (verified) — one additive routing-DSL `include` only | None (it's pure-Ruby value objects; also does nothing) |
| **Verdict** | **Reference design — own it** (optional short-term bridge-depend) | **Skip** (borrow the chain/registry topology only) |

---

## `gates` — skip (borrow one idea)

`gates` frames itself after Stripe's "Move fast, don't break your API," but the code is a **version-scoped
feature-flag table**: `ApiVersion#enabled?(:gate)` returns whether a named boolean is active for a version, by
walking a predecessor chain (`api_version.rb:5-15`). There is **no transform code at all** — nothing reads or
rewrites a request, params, or a response document; *you* branch on the boolean in your own code, which scatters
version conditionals through business/serializer logic — the exact coupling Stripe/Cadwyn exist to eliminate.
Version ids are opaque strings ordered by YAML declaration order (`manifest.rb:9`) — date-*shaped* but never
parsed or compared. No transport (header/param resolution is illustrative pseudo-code in the README). It's also
buggy (`Gates.load` misuses `Psych.parse_file`; the predecessor chain uses `.first` instead of `.last`, wrong for
≥3 versions — both reproduced on Ruby 3.4.7).

**Take exactly one thing:** the *topology* — versions as a linked predecessor chain + an `id → version` registry
for O(1) resolution. Reimplement it correctly (parse/sort real dates; plugin-extensible registry) and hang
*actual transforms* on each version edge — which is precisely what `gates` omits. It sits at ~10–15% of the
ambition we need. **Do not fork or depend.**

---

## `request_migrations` — the reference design

This is the real candidate, and architecturally it's what we want.

**The transform unit** — a subclass of `RequestMigrations::Migration` with a 3-method class DSL (`migration.rb:44-104`):
- `request(if:) { |req| … }` — runs **before** the action on the live `ActionDispatch::Request` → **up-migrate** old input to latest.
- `response(if:) { |res| … }` — runs **after** the action on the `ActionDispatch::Response` → **down-migrate** latest output to the requested version.
- `migrate(if:) { |data| … }` — content-agnostic transform over an arbitrary hash/array; you invoke it (e.g. for webhooks/jobs) via the standalone `Migrator`.

Each block is gated by an `:if` proc, idiomatically Ruby pattern-matching over the payload — and the README/specs
show it matching JSON:API collections directly (`data: [*, {type:, attributes:}]`). One class = one version-change
bundle holding both directions. Example (from the gem's own spec):

```ruby
Class.new(RequestMigrations::Migration) do
  description %(combine first and last name into a single field)
  migrate if: -> data { data in { type: 'user' } } do |data|
    data[:name] = "#{data.delete(:first_name)} #{data.delete(:last_name)}"
  end
  response if: -> res { res.request.params in { action: 'show' } } do |res|
    data = JSON.parse(res.body, symbolize_names: true); migrate!(data); res.body = JSON.generate(data)
  end
end
```

**Version transport — flexible, fits us directly.** A `config.request_version_resolver` proc is handed the
request and returns the target version (`configuration.rb:16-18`), so it reads any header — `Discourse-Api-Version`
works as-is. **`:date` is a first-class format** (`Date.parse`, `version.rb:21` — verified). Omitting the
latest-fallback + rescuing `UnsupportedVersionError`/`InvalidVersionError` into a 400 gives us the **mandatory**
header we want. The `Migrator` selects versions `between?(target, current)` and applies them directionally —
`migrations.reverse` (oldest→newest) before the action for request-up, `migrations` (newest→oldest) after for
response-down (`controller.rb:15-33`). That's exactly our reversible chain.

**Red-flag check — CLEAN (verified directly against the clone).** No ActiveRecord references anywhere, no
`prepend`/`alias_method`/`class_eval`/`refine`. The *entire* global footprint is one additive
`ActionDispatch::Routing::Mapper.send(:include, Router::Constraints)` in the railtie (adds an opt-in
`version_constraint` routing method; overrides nothing). Blast radius = one `around_action` you opt into. This is
nothing like the global `JoinDependency` patch (Ransack/Polyamorous) that broke core for us.

**Where it falls short of our needs:**

| Our need | `request_migrations` | Gap |
|---|---|---|
| Mandatory `Discourse-Api-Version: YYYY-MM-DD` header | ✅ resolver proc + first-class `:date` | — |
| Always-latest; migrate DOWN on response | ✅ | — |
| Migrate UP on request/params | ✅ (you wire the rewrites) | — |
| Transforms over jsonapi-serializer document | ⚠️ content-agnostic: you `JSON.parse`/`generate` the response **body** per migration | **No JSON:API/document helpers** |
| Reversible down+up as a pair | ✅ structurally (one class, both blocks) | reversibility is convention, not verified |
| Writes via `Service::Base` | ✅ neutral (only reshapes params/body) | — |
| Plugin-extensible transform registry | ⚠️ a single global `config.versions` hash | **No namespacing / autodiscovery** |

Also minor: version keys are `.sort`ed as **strings** (`migrator.rb:44`) — correct for zero-padded `YYYY-MM-DD`,
latent bug for semver (irrelevant to us); routing `version_constraint` is semver-only (we don't need it).

---

## What the Kit adds on top (the two gaps)

Owning the design lets us fix its two gaps *and* integrate at a better seam than a bolt-on gem can:

1. **A JSON:API-document-aware base migration.** `request_migrations` re-`JSON.parse`/`JSON.generate`s the
   response *body string* in every migration — awkward and O(parses × chain length). Because the Kit *controls*
   the render step, our response-DOWN transforms run on the **serializer's output hash before JSON-encoding**
   (parse-once, or never), with helpers for traversing JSON:API `data`/`included`/`meta`. Same for inbound params
   on the request-UP side. This is the concrete payoff of integrating at the serialization seam we already own.

2. **A namespaced, plugin-extensible registry.** Instead of one global mutable hash, a real registry keyed by
   version-date where **plugins register their own migrations** (ties directly to the deferred plugin question:
   does a plugin's breaking change advance the shared timeline or its own?). Lazy class resolution like
   `request_migrations` already does makes load-order-safe registration straightforward.

Everything else we lift close to verbatim: the `Migration` DSL (`request`/`response`/`migrate` + `:if`), the
`from/to` `Migrator` with directional application, the header-driven resolver, and the date `Version` type.

---

## Consistency with the team's philosophy

This lands the same way as the Kit-over-Graphiti decision: **own a small, spec-aligned, lock-in-free layer** rather
than depend on a framework. `request_migrations` is 546 LOC of clean, well-shaped prior art we can learn from and
lift — not a dependency worth carrying, given it's dormant, single-maintainer, weakly-CI'd, and missing our two
must-haves. The design is validated by a production system (Keygen) and mirrors Stripe/Cadwyn; we get the
confidence of proven architecture without the maintenance coupling.

---

## Sources

- `request_migrations`: repo https://github.com/keygen-sh/request_migrations · key files `lib/request_migrations/migration.rb`, `migrator.rb`, `controller.rb`, `version.rb`, `configuration.rb`, `railtie.rb`. Maintenance verified via rubygems + `gh`; red-flag + `:date` support verified directly against the clone.
- `gates`: repo https://github.com/phillbaker/gates · key files `lib/gates/manifest.rb`, `api_version.rb`, `gate.rb`. Dormancy + bugs verified via `gh`/rubygems and by running on Ruby 3.4.7.
- Prior context: [Stripe versioning reference](./stripe-api-versioning-reference.md), [Cadwyn review](./cadwyn-review.md).
