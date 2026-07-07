# Stripe API Versioning — Reference

*Last researched: 2026-07-07*

A precise, source-cited reference on how Stripe versions its API: the model, the
mechanics, the internal architecture, and how the scheme has evolved over time.
This is a standalone Stripe reference intended as a long-lived "beacon" for a team
designing a date-based API versioning system. It is **not** tailored to any
particular product.

> **Sourcing discipline.** Every non-obvious claim below is cited inline to a
> primary source (official Stripe docs, Stripe's engineering blog, or essays/talks
> by named Stripe engineers) where possible, with secondary sources clearly
> labelled. Stripe's scheme changed materially in **October 2024**, so historical
> and current (2026) states are described separately and date-stamped. A few
> details are known only from an engineering blog post and a conference talk
> (internal implementation) rather than from the official API reference — these are
> flagged explicitly in [§7](#7-internal-architecture-crown-jewel).

---

## Table of contents

1. [TL;DR / executive summary](#1-tldr--executive-summary)
2. [History & evolution](#2-history--evolution)
3. [Version identifier format & semantics](#3-version-identifier-format--semantics)
4. [Per-request version resolution](#4-per-request-version-resolution)
5. [Account version pinning](#5-account-version-pinning)
6. [Change classification (backwards-compatible vs breaking)](#6-change-classification)
7. [Internal architecture (crown jewel)](#7-internal-architecture-crown-jewel)
8. [Webhooks](#8-webhooks)
9. [Communication & process](#9-communication--process)
10. [Deprecation & long-term support](#10-deprecation--long-term-support)
11. [Trade-offs, costs & lessons learned](#11-trade-offs-costs--lessons-learned)
12. [The `/v2` namespace (aside)](#12-the-v2-namespace-aside)
13. [Implications for a homegrown implementation](#13-implications-for-a-homegrown-implementation)
14. [Bibliography](#14-bibliography)

---

## 1. TL;DR / executive summary

- **Date-based "rolling versions."** A Stripe API version is a calendar date. Since
  October 2024 it is a date plus a release codename, e.g. `2024-09-30.acacia`,
  `2025-03-31.basil`, `2026-06-24.dahlia`. There is no `v1`/`v2`/`v3`-style major
  version bump for the versioning axis. (`v1`/`v2` in the URL path is a separate
  concept — an API *namespace*, not a version; see [§12](#12-the-v2-namespace-aside).) — [Stripe API Reference: Versioning](https://docs.stripe.com/api/versioning); [Stripe blog, 2017](https://stripe.com/blog/api-versioning)
- **Backwards compatibility is a product promise.** Stripe states it has maintained
  compatibility with *every* version since the company's inception in 2011. Old
  versions are effectively never turned off. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)
- **Accounts are pinned on first use.** "Your version gets set the first time you make
  an API request," to the newest version available at that moment. It then stays
  fixed until you deliberately upgrade. — [API upgrades](https://docs.stripe.com/upgrades)
- **Per-request override.** A request may override the account default by sending a
  `Stripe-Version` header; modern SDKs pin their own version at build time. — [Stripe API Reference: Versioning](https://docs.stripe.com/api/versioning)
- **Additive changes never bump the version.** New resources, new optional request
  params, new response properties, new event types, reordered properties, and
  opaque-string format changes are all defined as backwards-compatible and ship
  without a new version. — [API upgrades](https://docs.stripe.com/upgrades)
- **Internal model (from a 2017 engineering blog + a talk, not the reference docs):**
  core code always produces the *latest* representation; a chain of ordered
  "version change" modules transforms the response *backwards* in time to whatever
  version the caller is pinned to. Old versions cost "fixed" (bounded) maintenance
  because each is encapsulated in one module. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)
- **New release process since Oct 2024.** Monthly *additive-only* releases plus
  *twice-yearly* major releases (breaking changes) named after plants, in
  alphabetical order: Acacia → Basil → Clover → Dahlia. — [Introducing Stripe's new API release process](https://stripe.com/blog/introducing-stripes-new-api-release-process); [Acacia changelog](https://docs.stripe.com/changelog/acacia)
- **Webhooks version independently.** A webhook endpoint carries its own API version
  (or falls back to the account default); each `Event`'s `data` is frozen at the
  `api_version` it was rendered with and never changes retroactively. — [Handle webhook versioning](https://docs.stripe.com/webhooks/versioning); [Event object](https://docs.stripe.com/api/events/object)
- **Safety rails today:** a **72-hour rollback window** after an account upgrade, and
  a documented parallel-endpoint procedure for migrating webhooks. — [API upgrades](https://docs.stripe.com/upgrades); [Handle webhook versioning](https://docs.stripe.com/webhooks/versioning)

---

## 2. History & evolution

**2011 — origin & the compatibility promise.** Stripe has, by its own account, "been
thinking about [its] API's contract since the company started" and "to date, [has]
maintained compatibility with every version of [its] API since [the] company's
inception in 2011." The guiding analogy: an API should be "as stable as possible,"
like a power company that "shouldn't change its voltage every two years." — [Stripe blog: "APIs as infrastructure", Brandur Leach, 2017-08-05](https://stripe.com/blog/api-versioning)

**Date-based rolling versions (original scheme).** From early on, Stripe rejected the
`v1/v2/v3` major-version model because "changes between versions [are] so big and so
impactful for users that it's almost as painful as re-integrating from scratch."
Instead each backwards-incompatible change spawned a new **rolling version named for
its release date**, e.g. `2017-05-24`, `2017-02-14`. Each version carries "a small set
of changes that make incremental upgrades relatively easy." — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)

**Scale by 2017.** Stripe reported "nearly a hundred backwards-incompatible upgrades
over the past six years," i.e. on the order of **10–20 new versions per year** in the
original scheme. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning); corroborated in [Brandur Leach, "Why Doesn't Stripe Automatically Upgrade API Versions?", 2017-03-17](https://brandur.org/api-upgrades)

**2014 talk (early public description).** Stripe's API lead **Amber Feng** described the
approach publicly in the Heavybit Speaker Series talk *"Move Fast, Don't Break the
API"* (circa 2014), which is the earliest public account of the "produce the latest
version internally, transform responses backward" model. — [Heavybit: "Move Fast, Don't Break the API" (Amber Feng)](https://www.heavybit.com/library/video/move-fast-dont-break-api) *(secondary/transcript-level; the full talk transcript was not retrievable during this research)*

**October 1, 2024 — the "new API release process."** Stripe restructured *how* versions
ship (not the date-based identifier itself). Previously it "released new API features
as soon as they're ready for production—regardless of whether they're
backward-compatible or not." The new process, announced by **Michael Glukhovsky**
(Product) and **Wissam Abirached** (Engineering Manager, API Services), introduced a
predictable cadence and named major releases. — [Introducing Stripe's new API release process, 2024-10-01](https://stripe.com/blog/introducing-stripes-new-api-release-process)

- **Monthly** releases contain **only backwards-compatible** changes and keep the
  current major release's name, "to denote that it's safe to upgrade."
- **Semiannual** major releases bundle breaking changes and get a new plant codename.

**Named major releases to date** (each "first version" is a breaking release; later
same-name versions are additive-only):

| Release | First (breaking) version | Date | Notes |
|---|---|---|---|
| **Acacia** | `2024-09-30.acacia` | 2024-09-30 | "the first release in our new API versioning model" — [Acacia changelog](https://docs.stripe.com/changelog/acacia) |
| **Basil** | `2025-03-31.basil` | 2025-03-31 | [Basil changelog](https://docs.stripe.com/changelog/basil) |
| **Clover** | `2025-09-30.clover` | 2025-09-30 | "the third release in our new API versioning model" — [Clover changelog](https://docs.stripe.com/changelog/clover) |
| **Dahlia** | `2026-03-25.dahlia` | 2026-03-25 | [Dahlia changelog](https://docs.stripe.com/changelog/dahlia) |

The cadence is a clean **March / September** semiannual rhythm, with additive monthly
releases in between.

**Current GA version (2026-07-07): `2026-06-24.dahlia`** — a June 2026 *monthly*
(additive) release under the Dahlia major line. — [Stripe API Reference: Versioning](https://docs.stripe.com/api/versioning); [SDK versioning & support policy](https://docs.stripe.com/sdks/versioning)

> **Source-conflict note.** The changelog *index* page, when summarized, produced
> inconsistent "first version" dates for some releases (it lists monthly release
> dates intermixed). The per-release changelog pages (Acacia/Basil/Clover/Dahlia,
> cited above) are authoritative and mutually consistent, so those dates are used
> here.

**Also new since ~2024:** a separate **`/v2` API namespace** launched alongside the new
release process (the earliest v2 examples use `2024-09-30.acacia`). This is a
different request/response *design*, not a new versioning axis; it still uses the same
date-based `Stripe-Version` header. See [§12](#12-the-v2-namespace-aside). — [API v2 overview](https://docs.stripe.com/api-v2-overview)

---

## 3. Version identifier format & semantics

**Format.**

- **Original scheme (pre-Acacia, i.e. before 2024-09-30):** a bare ISO date,
  `YYYY-MM-DD` (e.g. `2017-05-24`, `2019-02-19`). — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)
- **Current scheme (Acacia onward, from 2024-09-30):** `YYYY-MM-DD.<release_name>`,
  e.g. `2024-09-30.acacia`, `2026-06-24.dahlia`. The date is the release date; the
  suffix is the plant codename of the major release the version belongs to. — [Stripe API Reference: Versioning](https://docs.stripe.com/api/versioning); [Acacia changelog](https://docs.stripe.com/changelog/acacia)
- **Preview channel:** a `.preview` suffix (e.g. `2026-06-24.preview`) denotes the
  public-beta version rather than GA. — [SDK versioning & support policy](https://docs.stripe.com/sdks/versioning)

**What a "version" *is*.** A version is a labelled point in an append-only timeline of
API behavior. Each version is defined by the (small) set of backwards-incompatible
changes introduced at that date relative to the immediately preceding version. There
is **no semantic-version-style hierarchy** on the versioning axis — versions are
totally ordered by date, not grouped into `major.minor.patch`. (Semantic versioning
*does* apply, separately, to the client **SDK libraries** — see [§4](#4-per-request-version-resolution) and [§10](#10-deprecation--long-term-support).) — [SDK versioning & support policy](https://docs.stripe.com/sdks/versioning)

**Two "tiers" of change under the current model:**

- A **major release** (twice a year, new plant name) is the *only* place breaking
  changes appear.
- A **monthly release** carries the same plant name as the current major and contains
  only additive changes; "You can safely upgrade to a new monthly release without
  breaking any existing code." — [Stripe API Reference: Versioning](https://docs.stripe.com/api/versioning)

**How many versions exist.** Historically, ~100 backwards-incompatible versions had
accumulated by 2017 (10–20/year). — [Stripe blog, 2017](https://stripe.com/blog/api-versioning). Under the current model, breaking changes are batched into just **two major releases per year**, but additive monthly releases still each get their own dated string, so distinct version strings continue to accumulate roughly monthly. Every version ever issued remains valid (see [§10](#10-deprecation--long-term-support)).

---

## 4. Per-request version resolution

For any given API request, Stripe resolves a single **target API version**, then renders
the response in that version. The resolution order (highest priority first) in the
**current** model is:

1. **Explicit per-request / global override** — a `Stripe-Version` request header, or
   the equivalent global property set in an SDK (e.g. `Stripe.api_version` in Ruby,
   `apiVersion` in the Node constructor, `StripeConfiguration.ApiVersion` in .NET).
   **Highest priority.**
2. **SDK version pinning** — modern SDK major versions pin the API version that was
   current when that SDK version was published, and send it automatically. This applies
   to e.g. stripe-node v12+, stripe-ruby v9+, stripe-python v6+, stripe-php v11+, and
   the strongly-typed SDKs (Java via `Stripe.API_VERSION`, Go via `stripe.APIVersion`,
   .NET via `StripeConfiguration.ApiVersion`), which are fixed to the API version at
   SDK release time. Older SDK major versions (e.g. stripe-node ≤ v11) did **not** pin
   and fell through to the account default.
3. **Webhook endpoint's configured version** — applies specifically to *event
   rendering* for that endpoint (see [§8](#8-webhooks)), not to ordinary API calls.
4. **Account default version** (set in **Workbench**) — the fallback when nothing above
   applies. **Lowest priority.**

— [Stripe API Reference: Versioning](https://docs.stripe.com/api/versioning)

**Connect / OAuth authorization.** When a Connect **platform** makes requests on behalf
of connected accounts *without* specifying a version, "Stripe always uses the
platform's API version. Regardless of a connected account's API version, the
platform's requests on its behalf always return responses matching the API version of
the request." — [API upgrades](https://docs.stripe.com/upgrades). The original (2017) description of the resolution order was three-level and named this explicitly: `Stripe-Version` header → "the version of an authorized OAuth application if the request is made on the user's behalf" → the user's pinned version. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)

**Historical vs current.** The 2017 order had three tiers (header → OAuth-app version →
account pin). SDK-level pinning (tier 2 above) and endpoint-level webhook versioning
(tier 3) were layered on later; SDK pinning in particular arrived with the newer SDK
major versions and the 2024 release process. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning); [SDK versioning & support policy](https://docs.stripe.com/sdks/versioning)

**If none is sent.** With no header/SDK pin, the request uses the **account's pinned
default** (see [§5](#5-account-version-pinning)). Stripe's own guidance is to *not* rely on the account
default and instead pin explicitly in code. — [API upgrades](https://docs.stripe.com/upgrades)

**Organization API keys.** All requests made with an **organization API key** are
*required* to include the `Stripe-Version` header, "to ensure consistency and
predictability across your organization's integrations." — [SDK versioning & support policy](https://docs.stripe.com/sdks/versioning)

---

## 5. Account version pinning

**Set on first request.** "Your version gets set the first time you make an API
request." The 2017 blog and Brandur's essay are more explicit about the mechanism: "The
first time a user makes an API request, their account is automatically pinned to the
most recent version available" / "automatically locked to the current version of the
API." After that the pin is stable — Stripe does not silently move accounts forward. — [API upgrades](https://docs.stripe.com/upgrades); [Stripe blog, 2017](https://stripe.com/blog/api-versioning); [Brandur, "Why Doesn't Stripe Automatically Upgrade…", 2017](https://brandur.org/api-upgrades)

**Why no auto-upgrade.** Brandur Leach's essay explains the deliberate "safety-first"
choice: Stripe can detect *some* safe upgrades from endpoint usage, but "too many
changes fall into [an] ambiguous area" (e.g. a default-collapsing change on a resource
the user calls) where safety can't be measured, "so we don't" auto-upgrade. — [Brandur, 2017](https://brandur.org/api-upgrades)

**Upgrading (current Dashboard/Workbench flow).** API version is managed in
**Workbench** (the Dashboard developer surface). To upgrade: open the **Overview** tab
in Workbench → in the **API version** section click the available-upgrade control →
confirm the target version → **Upgrade**. This switches (a) API calls made *without* a
`Stripe-Version` header and (b) webhook object rendering to the new version. — [API upgrades](https://docs.stripe.com/upgrades). Stripe recommends testing the new version with the `Stripe-Version` header *before* committing the account-level upgrade. — [Stripe API Reference: Versioning](https://docs.stripe.com/api/versioning)

**Rollback IS possible (bounded).** "For 72 hours after you've upgraded your API
version, you can safely roll back to the version you were upgrading from in Workbench."
On rollback, "webhooks sent with the new object structure that failed are retried with
the old structure." — [API upgrades](https://docs.stripe.com/upgrades)

**Test vs live mode.** The `Stripe-Version` header can be set "in live or testing
environments" to try a newer version without changing the account default. — [API upgrades](https://docs.stripe.com/upgrades). (The account default pin itself is per-mode in practice; the header override works in both.)

---

## 6. Change classification

Stripe publishes an **explicit list** of what it treats as **backwards-compatible**
(safe to ship into existing versions, *no* new version required). Reproduced verbatim
from the official upgrades page:

> **Backward-compatible changes.** Stripe considers the following changes to be
> backward-compatible:
> - Adding new API resources.
> - Adding new optional request parameters to existing API methods.
> - Adding new properties to existing API responses.
> - Changing the order of properties in existing API responses.
> - Changing the length or format of opaque strings, such as object IDs, error
>   messages, and other human-readable strings.
>   - This includes adding or removing fixed prefixes (such as `ch_` on charge IDs).
>   - Make sure that your integration can handle Stripe-generated object IDs, which
>     can contain up to 255 characters. […] store the IDs in a
>     `VARCHAR(255) COLLATE utf8_bin` column […].
> - Adding new event types.
>   - Make sure that your webhook listener gracefully handles unfamiliar event types.

— [API upgrades (English)](https://docs.stripe.com/upgrades)

**Implications of the list (Stripe's stated contract):** clients must tolerate
unexpected new fields, new enum/event-type values, reordered JSON keys, and
longer/reformatted opaque IDs *without* breaking. In effect these are the "you must be
a tolerant reader" rules that let Stripe ship features continuously without a version
bump.

**Breaking changes (require a new version).** Stripe's docs define breaking changes
mostly by exclusion — anything *not* on the backwards-compatible list. The engineering
blog and Brandur's essay give concrete examples of what counts as breaking:

- Removing a previously-present response field. — [Brandur, 2017](https://brandur.org/api-upgrades)
- Changing a field's JSON **type** (e.g. `String` → `Hash`). — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)
- Renaming a field, or replacing a field's meaning (e.g. the 2014 replacement of a
  `verified` boolean with a `status` field). — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)
- Changing default behavior in a way an integration could observe (e.g. collapsing a
  sub-resource by default). — [Brandur, 2017](https://brandur.org/api-upgrades)

Under the **current** model, all such breaking changes are held for a **major
(plant-named) release** and each is documented as a `Breaking` entry in the changelog.
Examples from the Basil major (`2025-03-31.basil`): removing/reorganizing legacy
usage-based billing, migrating the Upcoming Invoice API to a Create Preview API,
deprecating `total_count` expansion on list methods, and deferring subscription
creation in Checkout Sessions until after payment. — [Basil changelog](https://docs.stripe.com/changelog/basil)

---

## 7. Internal architecture (crown jewel)

> **Provenance / confidence.** This section describes Stripe's *internal
> implementation*. It is documented in Stripe's **engineering blog post** ("APIs as
> infrastructure", Brandur Leach, 2017) and an earlier **conference talk** (Amber
> Feng, Heavybit, ~2014) — **not** in the official API reference. The code shown in
> the blog is illustrative and reflects the **circa-2017** internal design; details
> may have changed. Treat the *model* as well-corroborated and the *specific
> class/DSL shapes* as "as described in a 2017 blog post."

### The core idea: always operate on the latest representation, transform backward

Stripe's business logic and serializers only ever produce the **current** version of a
resource. Old versions are not implemented with `if version < X` branches sprinkled
through the code. Instead:

> "When generating a response, the API initially formats data by describing an API
> resource at the current version, then determines a target API version […] It then
> walks back through time and applies each version change module [it] finds along the
> way until that target version is reached." — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)

Amber Feng's talk is summarized to the same effect: engineers "only write code for the
latest version and do not clutter the core business logic with 'if-else' chains"; once
the modern response exists, "the response compatibility layer takes over and transforms
the data backward to match whatever version the client expects." — [Heavybit talk summary](https://www.heavybit.com/library/video/move-fast-dont-break-api) *(secondary summary of the talk)*

### A single version change as code

Each backwards-incompatible change is encapsulated in **one "version change" module**
that bundles (a) human-readable documentation, (b) a declaration of the field/type
delta, and (c) a transform function. As shown in the 2017 blog (illustrative Ruby):

```ruby
class CollapseEventRequest < AbstractVersionChange
  description "Event objects (and webhooks) will now render `request`
    subobject that contains a request ID and idempotency key instead
    of just a string request ID."
  response EventAPIResource do
    change :request, type_old: String, type_new: Hash
    run do |data|
      data.merge(:request => data[:request][:id])
    end
  end
end
```

The API resources themselves are declared via a DSL that enumerates allowed fields, e.g.:

```ruby
class ChargeAPIResource
  required :id, String
  required :amount, Integer
end
```

— [Stripe blog, 2017](https://stripe.com/blog/api-versioning)

### Ordering: a dated registry, applied newest→oldest

Version changes are registered against the dated version that introduced them, in a
central map, and are "written so that they expect to be automatically applied backwards
from the current API version and in order":

```ruby
class VersionChanges
  VERSIONS = {
    '2017-05-25' => [Change::AccountTypes, Change::CollapseEventRequest,
      Change::EventAccountToUserID],
    '2017-04-06' => [Change::LegacyTransfers],
    # ...
  }
end
```

So a response for a caller pinned at `2017-04-06` is produced at "current," then each
change dated *after* `2017-04-06` is applied in reverse-chronological order to
down-convert it. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)

### Response-DOWN vs request-UP transforms — an important gap in the public record

- **Response (down) transforms are the documented mechanism.** Every code example and
  every description in the 2017 blog concerns transforming an outbound response from
  the latest representation *down* to the target version. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)
- **Request (up) transforms are NOT described in the public material.** The blog does
  not describe converting inbound request parameters from an old version *up* to the
  current shape. Logically some request-side handling must exist (e.g. when a required
  parameter is added or a param is renamed in a breaking release), but **how Stripe
  does request-side up-conversion is not publicly documented**, and this is a genuine
  uncertainty rather than a settled fact. A close open-source reimplementation of the
  Stripe model, **Cadwyn**, explicitly adds **bidirectional (request *and* response)
  migrations**, and its author frames request migrations as an advance "beyond
  Stripe's documented approach, which focused primarily on response transformations."
  — [Convoy interview with Stanislav Zmiev (Cadwyn author)](https://www.getconvoy.io/blog/interview-with-stanislav-zmiev) *(secondary)*

### Side effects and composition

Not every breaking change is a pure data reshape. The blog notes changes can be
annotated `has_side_effects`, in which case the transform is "a no-op" but code
elsewhere can branch on whether the change is active (e.g. `VersionChanges.active?
(ModuleName)`). Stripe acknowledges this reduces encapsulation and is "less
maintainable." Because transforms are ordered and each targets a specific resource
type, they compose as a pipeline; the design intent is that each is a small, isolated,
independently-testable delta. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)

### Design principles Stripe states for the whole scheme

1. **Lightweight** — "Make upgrades as cheap as possible (for users and for
   ourselves)."
2. **First-class** — "Make versioning a first-class concept in your API so that it can
   be used to keep documentation and tooling accurate and up-to-date."
3. **Fixed-cost** — "Ensure that old versions add only minimal maintenance cost by
   tightly encapsulating them in version change modules."

— [Stripe blog, 2017](https://stripe.com/blog/api-versioning)

> **Caveat on "Gates".** Some secondary write-ups describe Stripe using a separate
> "Gates" mechanism alongside transformation modules. That specific term is *not* in
> the primary 2017 blog post (which uses `has_side_effects` / `VersionChanges.active?`
> for conditional behavior). Treat "Gates" as an unverified secondary
> characterization.

---

## 8. Webhooks

Webhooks version **independently** of your API calls.

**Endpoint version vs account default.** "Webhook endpoints have a specific API version
set or use the default API version of the Stripe account." An endpoint pinned to a
version renders its event payloads at that version regardless of the account default. — [Handle webhook versioning](https://docs.stripe.com/webhooks/versioning); [API upgrades](https://docs.stripe.com/upgrades)

**Events are frozen at creation.** The `Event` object's `api_version` attribute is "The
Stripe API version used to render `data` when the event was created. The contents of
`data` never change, so this value remains static regardless of the API version
currently in use." (Populated for events created on/after 2014-10-31.) So a stored
event's structure is immutable even if you later upgrade the account. — [Event object](https://docs.stripe.com/api/events/object)

**Static-typed SDK caveat.** If you process events with a statically-typed SDK (.NET,
Java, Go), the endpoint's API version must match the version the SDK was generated
against. — [Handle webhook versioning](https://docs.stripe.com/webhooks/versioning)

**Safe webhook upgrade = the parallel-endpoint pattern.** Stripe documents a
cut-over procedure so you never silently drop events during a version migration:

1. Create a **second** webhook endpoint at the *same* URL (disambiguated by a query
   param, e.g. `https://example.com/webhooks?version=2024-04-10`) with `api_version`
   set to the target version.
2. During overlap, **every event is delivered twice** — once at the old version and
   once at the new. Handle the old ones; ignore the new ones (return `200`) until
   ready.
3. Flip your handler: process new-version events; for old-version events return a
   `400` so Stripe **retries** them (giving you a safety margin) rather than dropping
   them.
4. Once cut over, disable the old endpoint.

— [Handle webhook versioning](https://docs.stripe.com/webhooks/versioning)

> **Source nuance.** The account-upgrade page describes an automatic **72-hour
> rollback** with retry of failed new-structure webhooks ([API upgrades](https://docs.stripe.com/upgrades)); the webhook-versioning guide instead documents the manual parallel-endpoint procedure above and does not itself restate the 72-hour window. Both are current; they address different scenarios (account-wide upgrade vs endpoint-scoped migration).

**Thin / lightweight events.** Events emitted by the `/v2` namespace are "lightweight
events" (they carry references, not full object snapshots, so you fetch current state
on receipt). Lightweight events for `/v1` resources were, as of this research, in
private beta (previously v2-only). — [API v2 overview](https://docs.stripe.com/api-v2-overview); [Handle webhook versioning](https://docs.stripe.com/webhooks/versioning)

---

## 9. Communication & process

**Programmatically-generated changelog.** "Our API changelog is programmatically
generated and receives updates as soon as services are deployed with a new version." — [Stripe blog, 2017](https://stripe.com/blog/api-versioning). The current developer changelog ([docs.stripe.com/changelog](https://docs.stripe.com/changelog)) is filterable by API version and tags each entry `Breaking` / `Non-breaking` with the affected products and a link to a per-change doc page. — [Changelog](https://docs.stripe.com/changelog); [Basil changelog](https://docs.stripe.com/changelog/basil)

**Version-aware documentation.** The docs "detect the user's API version and present
relevant warnings" about breaking changes in newer versions — versioning is used as a
first-class input to tooling and docs. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)

**Predictable release calendar (since 2024).** The new release process makes breaking
changes *scheduled and batched* (twice yearly) rather than continuous, so integrators
can plan upgrades; monthly releases are explicitly signalled as safe by reusing the
current major's name. Each major release ships an upgrade guide via its changelog. — [Introducing Stripe's new API release process](https://stripe.com/blog/introducing-stripes-new-api-release-process); [Stripe API Reference: Versioning](https://docs.stripe.com/api/versioning)

**Preview channel.** Public-beta features ship on `.preview` versions and corresponding
beta-tagged SDK builds, letting integrators try changes before they land in a GA major
release. — [SDK versioning & support policy](https://docs.stripe.com/sdks/versioning)

---

## 10. Deprecation & long-term support

**API versions are effectively never retired.** The whole premise is that Stripe
"maintained compatibility with every version of [its] API since […] 2011" ([Stripe
blog, 2017](https://stripe.com/blog/api-versioning)), and the internal transform-chain is designed so that keeping an old version alive is a bounded, "fixed-cost" per-version maintenance item ([§7](#7-internal-architecture-crown-jewel)). No public source found in this research documents Stripe force-retiring an old *API version* / turning it off. This is the strong, distinguishing feature of the model: the deprecation horizon for a pinned integration is, in practice, indefinite.

**What *does* have a deprecation policy: SDK libraries and language runtimes.** These
are separate from API versions.

- SDK libraries use **semantic versioning**; each SDK version is tied to the API
  version current at its publication. New features/fixes land only on the **latest
  major** SDK version; older SDK majors "remain available, but […] receive no further
  updates." — [SDK versioning & support policy](https://docs.stripe.com/sdks/versioning)
- SDKs track **language-runtime** end-of-life: when a runtime reaches EOL, Stripe marks
  it deprecated and starts an **extended-support period of roughly 1–2 years** (varies
  by language) before dropping it from new SDK majors. Examples documented: Ruby ~1.5
  years (three API majors); Python/Node/Go ~1 year (two API majors). — [SDK versioning & support policy](https://docs.stripe.com/sdks/versioning)

**Rollback window.** The one explicit time-boxed policy on the versioning side is the
**72-hour** post-upgrade rollback (see [§5](#5-account-version-pinning)). — [API upgrades](https://docs.stripe.com/upgrades)

> **Distinction to keep straight:** "how long is my *pinned API version* supported?" →
> effectively forever. "How long is my *SDK / language runtime* supported?" → bounded
> (latest major SDK only; ~1–2 yr runtime extended support). Conflating the two is a
> common error.

---

## 11. Trade-offs, costs & lessons learned

**The upside Stripe emphasizes.** Continuous shipping of additive features without
version churn; customers who never *have* to upgrade; breaking changes isolated into
small, dated, documented, testable deltas; and a versioning primitive that also powers
docs, changelog, and tooling. The "fixed-cost" principle is the crux: encapsulating
each version in one module is what makes "compatibility since 2011" sustainable. — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)

**The cost / what's hard.**

- **Maintenance is bounded, not free.** Every old version is a transform (or several)
  that must keep working forever; the chain grows monotonically. `has_side_effects`
  changes leak version-awareness out of the transform layer and are explicitly called
  out as "less maintainable." — [Stripe blog, 2017](https://stripe.com/blog/api-versioning)
- **Auto-upgrade is intractable in general.** Stripe deliberately does *not* auto-move
  accounts forward because too many changes are ambiguously safe — meaning the human
  upgrade cost is pushed onto integrators, and long-tail accounts can sit on very old
  versions indefinitely. — [Brandur, 2017](https://brandur.org/api-upgrades)
- **"Upgrade fatigue" / unpredictability of the *old* scheme.** The pre-2024 model
  shipped breaking changes whenever ready, which the 2024 announcement implicitly
  critiques by introducing a predictable, batched cadence — a direct lesson-learned. — [Introducing Stripe's new API release process, 2024](https://stripe.com/blog/introducing-stripes-new-api-release-process)
- **Client codegen complexity.** Because SDKs are generated against specific API
  versions and Stripe supports many, keeping typed SDKs coherent across versions is
  non-trivial (Brandur has written separately about the state of Stripe's API library
  codegen). — [Brandur, "The state of Stripe API library codegen"](https://brandur.org/fragments/stripe-codegen) *(primary, engineer's blog)*

**External reception.** The approach is widely admired and copied — the 2017 essay is
frequently cited as the reference for "rolling/date-based versioning." A notable
reimplementation is **Cadwyn** (FastAPI), whose author says he was "immediately amazed"
by Stripe's approach and reports that with automation "the cost of supporting each
version has become almost unnoticeable"; he also notes the model has "a steeper initial
learning curve." Cadwyn extends the model with **type safety** and **bidirectional
(request + response) migrations**, which it presents as improvements over Stripe's
publicly-documented (response-focused) design. — [Convoy interview with Stanislav Zmiev](https://www.getconvoy.io/blog/interview-with-stanislav-zmiev) *(secondary)*; discussion also on [Hacker News](https://news.ycombinator.com/item?id=15020726) *(secondary)*

---

## 12. The `/v2` namespace (aside)

`/v2` is often confused with a "version 2" of the versioning scheme. **It is not.** It is
a separate **API namespace** with modernized request/response *design*, launched around
the 2024 release process. Both coexist and can be mixed in one integration
("You can use all combinations of APIs in the `/v1` or `/v2` namespace in the same
integration"). — [API v2 overview](https://docs.stripe.com/api-v2-overview)

Key differences (design, not versioning): `/v2` uses JSON request bodies (vs `/v1`
form-encoding), token/URL-based pagination (vs cursor properties), a longer idempotency
window that re-runs failed requests, `include` (vs `expand`), `null`-based metadata
deletion, eventual consistency by default, and lightweight events. — [API v2 overview](https://docs.stripe.com/api-v2-overview)

Crucially for versioning: **`/v2` still uses the same date-based `Stripe-Version`
header** — indeed "All requests […] sent to the `/v2` API namespace must include the
`Stripe-Version` header" — so the date-based versioning model spans both namespaces. — [API v2 overview](https://docs.stripe.com/api-v2-overview)

---

## 13. Implications for a homegrown implementation

Neutral, factual takeaways from the Stripe model (not recommendations for any specific
product):

- **Identifier:** a totally-ordered, human-meaningful key (a date) avoids the
  "re-integrate from scratch" cliff of `v1→v2` jumps. A codename-per-major-release
  layer (Stripe's post-2024 addition) buys human memorability + a clear "safe to
  upgrade" signal for additive monthly releases.
- **Pin-on-first-use + explicit-override** gives stability by default and control on
  demand. Precedence must be defined unambiguously (Stripe: explicit override → SDK pin
  → endpoint/OAuth context → account default).
- **A published, exhaustive backwards-compatible list** is what makes continuous
  additive shipping safe — it doubles as the "tolerant reader" contract clients must
  honor (accept unknown fields/enums, tolerate reordering and ID-format changes).
- **Transform-chain internals:** keep core logic on the latest representation; express
  each breaking change as one ordered, dated, documented, independently-tested
  migration applied backward for responses. Budget explicitly for the fact that
  **request-side (up) migrations are needed too** — Stripe's public writeups under-
  specify this, and reimplementations (Cadwyn) treat bidirectional migrations as
  essential.
- **Versioning is cross-cutting:** wiring it into changelog generation, docs, and SDK
  codegen (not just the response serializer) is where much of the leverage — and much
  of the cost — lives.
- **Webhooks need their own version story:** freeze event payloads at creation, let
  endpoints pin versions, and provide a dual-delivery cut-over path.
- **Cost profile:** compatibility "forever" is feasible only if per-version cost is
  bounded (one encapsulated module) *and* breaking changes are rare/batched; side-
  effecting changes and typed-SDK codegen are the parts that erode that bound.

---

## 14. Bibliography

### Primary — Stripe official documentation
- **Versioning | Stripe API Reference** — Stripe. <https://docs.stripe.com/api/versioning> (current version, resolution precedence, SDK pinning; accessed 2026-07-07; shows current GA `2026-06-24.dahlia`)
- **API upgrades** — Stripe. <https://docs.stripe.com/upgrades> (backwards-compatible change list, first-request pinning, Workbench upgrade flow, 72-hour rollback, Connect behavior; accessed 2026-07-07)
- **Stripe versioning and support policy (SDKs)** — Stripe. <https://docs.stripe.com/sdks/versioning> (SDK↔API version coupling, monthly/semiannual cadence, deprecation/EOL policy, preview channel, org-API-key header requirement; accessed 2026-07-07)
- **Set a Stripe API version** — Stripe. <https://docs.stripe.com/sdks/set-version> (per-SDK version-setting mechanics)
- **API v2 overview** — Stripe. <https://docs.stripe.com/api-v2-overview> (v1 vs v2 namespace; v2 requires `Stripe-Version`; accessed 2026-07-07)
- **Handle webhook versioning** — Stripe. <https://docs.stripe.com/webhooks/versioning> (endpoint version, parallel-endpoint upgrade procedure, static-SDK caveat, thin events; accessed 2026-07-07)
- **Event object (`api_version`)** — Stripe API Reference. <https://docs.stripe.com/api/events/object> (frozen `data`/`api_version` semantics; accessed 2026-07-07)
- **Developer changelog** — Stripe. <https://docs.stripe.com/changelog> (version-filterable, Breaking/Non-breaking tagging; accessed 2026-07-07)
- **Acacia changelog** — Stripe. <https://docs.stripe.com/changelog/acacia> (`2024-09-30.acacia`, "first release in our new API versioning model")
- **Basil changelog** — Stripe. <https://docs.stripe.com/changelog/basil> (`2025-03-31.basil`; example breaking changes)
- **Clover changelog** — Stripe. <https://docs.stripe.com/changelog/clover> (`2025-09-30.clover`, "third release")
- **Dahlia changelog** — Stripe. <https://docs.stripe.com/changelog/dahlia> (`2026-03-25.dahlia`)

### Primary — Stripe engineering blog & Stripe engineers
- **"APIs as infrastructure: future-proofing Stripe with versioning"** — Brandur Leach (Stripe), Stripe Blog, **2017-08-05**. <https://stripe.com/blog/api-versioning> (the crown-jewel account of date-based rolling versions and the internal transform-chain architecture; note: describes internal implementation circa 2017)
- **"Introducing Stripe's new API release process"** — Michael Glukhovsky & Wissam Abirached (Stripe), Stripe Blog, **2024-10-01**. <https://stripe.com/blog/introducing-stripes-new-api-release-process> (monthly-additive + semiannual-major cadence, plant codenames, SDK↔release coupling)
- **"Why Doesn't Stripe Automatically Upgrade API Versions?"** — Brandur Leach, **2017-03-17**. <https://brandur.org/api-upgrades> (rationale for no auto-upgrade; pin-on-first-request)
- **"The state of Stripe API library codegen"** — Brandur Leach. <https://brandur.org/fragments/stripe-codegen> (SDK codegen complexity across versions)
- **"Move Fast, Don't Break the API"** — Amber Feng (Stripe), Heavybit Speaker Series, ~2014. <https://www.heavybit.com/library/video/move-fast-dont-break-api> (earliest public description of the model; full transcript not retrieved during this research — treat specifics as talk-level)

### Related primary (adjacent, for context)
- **"Version Variants"** — Brandur Leach, **2015-02-17**. <https://brandur.org/version-variants> ⚠️ *Describes **Heroku's** variant mechanism, NOT Stripe's. Included only as adjacent prior art from the same author; do not attribute variants to Stripe.*

### Secondary — analyses, interviews, discussion (clearly labelled)
- **Convoy Blog — interview with Stanislav Zmiev (author of Cadwyn)** — <https://www.getconvoy.io/blog/interview-with-stanislav-zmiev> (Cadwyn as a Stripe-style reimplementation with bidirectional migrations + type safety; maintenance-cost commentary)
- **Hacker News discussion of the 2017 Stripe post** — <https://news.ycombinator.com/item?id=15020726>
- **"Stripe's API Versioning Explained – Dates, Safety Rails, and Migrations"** — AverageDevs. <https://www.averagedevs.com/blog/stripe-api-versioning-explained> *(secondary teardown; returned HTTP 403 during this research and could not be independently verified — listed for completeness only)*
- **"Why Stripe's API Never Breaks: A Deep Dive into Date-Based Versioning"** — Yukesh A S, Medium. <https://medium.com/@asyukesh/why-stripes-api-never-breaks-a-deep-dive-into-date-based-versioning-a9925dd8af42> *(secondary)*

---

### Notable uncertainties & source conflicts flagged in this document
- **Request-side (up) transforms:** not described in Stripe's public material; existence is inferable but the mechanism is undocumented (see [§7](#7-internal-architecture-crown-jewel)).
- **"Gates":** appears in secondary write-ups but not in the primary 2017 blog; unverified (see [§7](#7-internal-architecture-crown-jewel)).
- **Changelog *index* dates:** the index summary yielded inconsistent "first version" dates; per-release changelog pages were used as authoritative (see [§2](#2-history--evolution)).
- **Internal code shapes** (`AbstractVersionChange`, `VersionChanges::VERSIONS`, `has_side_effects`) are from a **2017** blog and may no longer match Stripe's current implementation.
