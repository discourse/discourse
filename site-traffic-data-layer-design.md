# Site Traffic — Data Layer Design

> Sibling to `site-traffic-implementation-objectives.md`. The objectives doc describes what admins see; this doc describes the data layer underneath. Engineering reasoning, schema sketches, and trade-offs we considered are in scope; specific file paths, migration order, and code structure are deferred to implementation.

## Context

The redesigned admin dashboard's Site Traffic section needs a data path that:

- Powers the v1 cards (headline, KPI, chart) consistently from one source.
- Leaves room for the deferred v1 cards (top referrers, top countries) and future metrics (unique visitors, session duration, bounce rate) without re-architecting.
- Honors the engineering-contract isolation rule: the existing `application_requests` table and legacy chart are not touched.
- Runs identically on Discourse-hosted (RDS), self-hosted, and CI.

## Decision

A **two-tier architecture**:

1. **Per-event tables** (Tier 1) — new tables in core that capture one row per browser pageview, including everything the request emitted. Source of truth.
2. **Aggregate tables** (Tier 2) — new daily-summary tables, derived from Tier 1 by a scheduled rollup job. The dashboard reads from these.

Tier 2 powers the dashboard. Tier 1 powers re-derivation, ad-hoc investigation, and future metrics.

## Why this shape

We considered three alternatives during design:

| Option | Why rejected |
|---|---|
| **Counter tables only** (extend `application_requests` pattern with new dimensions) | Locks dimensions in forever; new metrics need backfill from zero; cross-dimension queries impossible; long-tail referrers require write-time top-N truncation that loses data permanently. |
| **Per-event only**, queried directly | Postgres without column-store extensions is too slow on dashboard queries for sites at the high end of the traffic distribution; needs a read cache anyway. |
| **External analytics warehouse** (S3+Athena, Redshift, etc.) | Doesn't run on self-hosted Discourse; AWS-specific path violates the "same code, anywhere" model. |

Two-tier (events + rollup) keeps the dashboard fast, keeps the source of truth flexible, and uses only stock Postgres.

## Tier 1: per-event table

Core owns the per-event table. It was introduced by
`DEV: Add browser pageview events (#39878)` and is gated by the hidden
`persist_browser_pageview_events` site setting:

```
browser_pageview_events
  id           bigint, primary key
  created_at   timestamp, not null
  url          string(2000), not null
  ip_address   inet, not null
  referrer     string(2000)
  user_agent   string(1000), not null
  session_id   string(32), not null
  country_code string(2)
  user_id      integer
  topic_id     integer

Indexes:
  (created_at) USING brin
  (user_id)
  (topic_id)
```

Notes:

- **BRIN index on `created_at`.** Append-only event log — BRIN is kilobytes vs. gigabytes for btree, and works perfectly for `WHERE created_at BETWEEN ?` scans.
- **`inet` type for IP.** Native v4/v6 support; cheap CIDR matching if ever needed.
- **No `req_type` column.** Logged-in vs. anonymous = `user_id IS NOT NULL`. Crawler pageviews are not in this table (crawlers don't fire JS); the chart's crawler series comes from `application_requests` (see "Crawler series", below).
- **Raw `referrer` and `url` stored verbatim.** No write-time parsing. Parsing happens at rollup time so changes to parser rules can recompute history.

### Write path

- Core middleware persists browser pageview rows via `Scheduler::Defer.later` when `persist_browser_pageview_events` is enabled.
- `country_code` is derived at write time by core from `ip_address` via `DiscourseIpInfo` (MaxMind GeoLite2).

### Rollout

Default behavior on existing sites: feature-flag-gated, off by default until the new dashboard section is enabled.

## Tier 2: aggregate table

The dashboard reads here. One day = one or more rows per dimensional combination.

```
browser_pageview_daily_aggregates
  date          date, not null
  country_code  string(2)        -- nullable: lookup miss
  source_name   string(100)      -- canonical display key; "Direct" / "(Other)"
  is_logged_in  boolean, not null
  count         integer, not null

Indexes:
  UNIQUE (date, country_code, source_name, is_logged_in) WHERE country_code IS NOT NULL
  UNIQUE (date, source_name, is_logged_in) WHERE country_code IS NULL
```

The first iteration dashboard reads human pageviews from `browser_pageview_daily_aggregates`, which is rolled up from core's `browser_pageview_events` table.

Cardinality math: ~250 countries × ~100 canonical source names × 2 logged-in values = **~50k rows/day worst case**. In practice 2–5k rows/day. Across years, the table stays small, tightly indexed, sub-second on every dashboard query.

`source_name` is intentionally a display/grouping key, not always a bare domain. Most referrers collapse to the canonical domain (`google.com`, `github.com`, `news.ycombinator.com`) to avoid path-cardinality explosions. Same-site referrers collapse to `(Internal)` so they can remain counted in pageview totals while staying out of the top-referrers card. Direct traffic remains a first-class source key because admins need to understand how much traffic landed without a referrer. Selected sources can preserve one meaningful path segment when it improves the top-referrers card without turning the summary table into full URL analytics. The initial exception is Reddit: `reddit.com/r/<subreddit>` is stored as the source key, while non-subreddit Reddit traffic collapses to `reddit.com`.

Full path-level drill-down still needs a separate summary table with `host_path` as a column and top-N + "Other" truncation per `(date, source_name)`. Schema and N parameter deferred.

### Rollup job

Runs every 5 minutes via Sidekiq (`Jobs::Scheduled`) when `persist_browser_pageview_events` is enabled. It re-aggregates yesterday and today from core's event table:

- `browser_pageview_events` -> `browser_pageview_daily_aggregates`

The rollup reads raw events for the selected UTC day in batches, derives
`source_name` in Ruby via `BrowserPageviewReferrerInspector`, groups rows by
`date`, `country_code`, `source_name`, and `is_logged_in`, then replaces that
day's aggregate rows in bulk.

Properties:

- **One pass over the selected day's events** populates the summary table.
- **Idempotent.** Re-runnable any number of times for any day within event retention. Used for backfill, parser changes, bug fixes.
- **No drift.** Every aggregate row's `count` equals `COUNT(*)` of the same source query. The dashboard's human pageview cards reconcile because they read from one underlying summary table.

### Today's partial-day data

The scheduled rollup re-aggregates today every 5 minutes. The dashboard reads only aggregate rows, so today's values can lag live traffic by up to one rollup interval.

### Crawler series

Crawler pageviews aren't in `browser_pageview_events` (crawlers don't fire JS). The chart's Crawlers filter pill reads from the existing `application_requests` table (`req_type = page_view_crawler`).

This is the one place the new section reads from the legacy table. Acceptable because the read is decoupled (the legacy table is not modified) and crawler-by-country/by-referrer is not in scope.

## Referrer parsing

Done at rollup time so changes to parser rules can rewrite history within retention.

- **Vendor Snowplow's `referers-latest.yaml`** in core and parse it directly in Ruby. The YAML is the valuable artifact; the upstream Ruby parser is stale enough that pulling it in as a runtime dependency is not worth it for this spike.
- **Optionally refresh the vendored YAML** from Snowplow's hosted artifact on a controlled cadence after the first iteration. This should be a developer-maintained update, not a dashboard runtime network dependency.
- **Add `custom_sources.yaml` later** if Discourse-specific overrides become common enough to justify a second data file.
- The parser returns `{ source, medium, term, domain }`. We use this as classification input, not as the final dashboard key. A Discourse wrapper converts the parsed result plus the original URL into `source_name`.
- The default `source_name` is the canonical domain from the parser (`google.com`, `github.com`, etc.). This consolidates noisy provider URLs such as Google search paths into one row.
- Unknown external referrers fall back to their normalized host instead of `(Other)`, so organic links from arbitrary sites are still visible in top-referrers. `(Internal)` is reserved for same-site referrers. `(Other)` is reserved for malformed URLs that cannot produce a host.
- Source-specific policies can override the default when path carries strong product value. Reddit is the first policy: if the URL host resolves to Reddit and the path starts with `/r/<subreddit>`, `source_name` becomes `reddit.com/r/<subreddit>`. Non-subreddit Reddit traffic collapses to `reddit.com`.
- `medium` (search/social/email) is captured for the future GA4-style "Channels" rollup if/when that's needed.

## Country derivation

- `DiscourseIpInfo.get(ip)` returns `country_code` from MaxMind GeoLite2 (already in core).
- Derived at write time, stored on the event row.
- `ZZ` (worldwide), `XX` (disputed), `T1` (Tor), and lookup misses are stored as `NULL` (rather than dropped). The dashboard hides `NULL` rows from cards by default.

## Retention

| Tier | What | Default retention | Rationale |
|---|---|---|---|
| Event row, `ip_address` column | nulled after **30 days** | Tightens privacy posture; per-IP investigation possible recently. |
| Event row, `user_id` column | nulled when user is deleted (`UserDestroyer`) | Already the convention for user-linked data. |
| Event row (entire) | dropped after **6 months** | Middle ground between GA4-Standard's 2 and 14 month options. |
| Aggregate rollup rows | **indefinite** | No PII, small footprint, useful for long-range reporting. |

All windows are knobs (site settings), not hard-coded. Self-hosted operators can extend; privacy-strict communities can shorten.

Implications:

- **Re-parseability of referrers** is bounded by the 6-month event retention. Older aggregate rows are frozen with whatever parser rules existed at rollup time.
- **Cross-dimension investigation** is bounded by the same 6 months.
- **Long-range trends** (Last 12 months and beyond) work fine — they read aggregates, which never expire.

## Privacy posture

- No raw IP or User-Agent ever exposed to admin UI; both are nulled or dropped on schedule.
- `user_id` is internal; deletion follows existing user-deletion semantics.
- Aggregates are PII-free by construction.
- This is more conservative than Plausible (who keep raw events forever, structurally anonymized via daily-rotating salt) and more permissive than GA4-Standard (2-month default deletion). Pragmatic middle.

## Engineering-contract isolation

- `application_requests` is not modified.
- The new section reads `application_requests` only for the chart's crawler series; it doesn't write there.
- The new section's tables are independent and can be feature-flagged or rolled back without touching legacy data.
- Existing site traffic report (the "See details" link target) and external consumers of `application_requests` continue to work unchanged.

## What this enables

### v1 (current objectives doc)

- Headline pageview total, logged-in share KPI, chart with daily/monthly bucketing, filter pills — all from `browser_pageview_daily_aggregates` + `application_requests` (crawler series).

### v1 deferred / v2

- **Top countries card**, **top referrers card** (source level), **referrer drill-down** (host+path level via separate summary table) — all derivable from the same Tier 1 events; new aggregates added as needed.

### v3+ (architecturally enabled, not committed)

- **Unique visitors KPI** via HyperLogLog sketches on `session_id` (requires `hll` extension; available on RDS, optional for self-hosted).
- **Session duration / bounce rate** via window functions over Tier 1 events at rollup time. No write-path changes needed.
- **GA4-style "Channels" rollup** (Search/Social/Direct/Referral/Email/etc.) using `medium` from the referrer parser.
- **Ad-hoc admin investigation** ("what did this user view?", "where did the May 7 spike come from?") via direct queries on Tier 1 within retention.

## Open questions for implementation

1. **Path-level drill-down summary table.** Schema, top-N parameter, "Other" bucket label — design when drill-down is scoped.
2. **`pg_partman` for `browser_pageview_events`.** If retention windows or growth rate justify it. Available on RDS; would need to bake into the official self-hosted Docker image. Not required for v1; defer.
3. **`hll` extension** for unique-visitor metrics. Optional; feature degrades to "exact distinct on small windows" if extension absent.
4. **Aggregate retention.** Core owns raw event retention via `clean_up_browser_pageview_events`; confirm whether dashboard aggregate rows are retained indefinitely.

## Non-goals for v1 of this data layer

- City-level geolocation. Country only.
- Per-event UTM tag parsing. Captured in `referrer` raw URL; not surfaced.
- Real-time streaming dashboards. Daily granularity, sub-second freshness via 5-min rollup at most.
- Cross-site analytics across multisite installations. Each site's data stays in its own scope.
- Webhooks or external streaming of pageview events. Internal-only data path.
