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

## Tier 1: per-event tables

Two tables, one per ingestion path (sync vs. beacon):

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

browser_pageview_events_beacon
  (same columns)

Indexes:
  (created_at) USING brin
  (user_id)
  (topic_id)
```

Notes:

- **Two tables, not one.** Mirrors the two emit points in core middleware (`request_tracker.rb` triggers `:browser_pageview` and `:beacon_browser_pageview` separately). A view consolidates them for queries that need everything.
- **BRIN index on `created_at`.** Append-only event log — BRIN is kilobytes vs. gigabytes for btree, and works perfectly for `WHERE created_at BETWEEN ?` scans.
- **`inet` type for IP.** Native v4/v6 support; cheap CIDR matching if ever needed.
- **No `req_type` column.** Logged-in vs. anonymous = `user_id IS NOT NULL`. Sync vs. beacon = which table. Crawler pageviews are not in these tables (crawlers don't fire JS); the chart's crawler series comes from `application_requests` (see "Crawler series", below).
- **Raw `referrer` and `url` stored verbatim.** No write-time parsing. Parsing happens at rollup time so changes to parser rules can recompute history.

### Write path

- Core middleware already fires `:browser_pageview` and `:beacon_browser_pageview` `DiscourseEvent`s when `trigger_browser_pageview_events` is enabled.
- Core subscribers persist a row per event via `Scheduler::Defer.later`, keeping inserts off the request hot path.
- `country_code` is derived at write time from `ip_address` via `DiscourseIpInfo` (MaxMind GeoLite2). `ZZ`/`XX`/`T1` and lookup misses are stored as `NULL`.

### Rollout

Default behavior on existing sites: feature-flag-gated, off by default until the new dashboard section is enabled.

## Tier 2: aggregate tables

The dashboard reads here. One day = one or more rows per dimensional combination.

```
pageview_daily_aggregates
  date          date, not null
  country_code  string(2)        -- nullable: lookup miss
  source_name   string(100)      -- canonical from referer-parser; "Direct" / "(Other)"
  is_logged_in  boolean, not null
  count         integer, not null
  PRIMARY KEY (date, country_code, source_name, is_logged_in)
```

Cardinality math: ~250 countries × ~100 canonical source names × 2 logged-in values = **~50k rows/day worst case**. In practice 2–5k rows/day. Across years, the table stays small, tightly indexed, sub-second on every dashboard query.

Path-level drill-down (e.g., `reddit.com/r/programming` under "Reddit") needs a separate summary table with `host_path` as a column and top-N + "Other" truncation per `(date, source_name)`. Schema and N parameter deferred.

### Rollup job

Runs nightly via Sidekiq (`Jobs::Scheduled`), one query per dimensional table:

```sql
INSERT INTO pageview_daily_aggregates (date, country_code, source_name, is_logged_in, count)
SELECT
  (created_at AT TIME ZONE 'UTC')::date,
  country_code,
  parse_referrer_source(referrer),
  user_id IS NOT NULL,
  COUNT(*)
FROM browser_pageview_events  -- plus UNION with the beacon table via a view
WHERE created_at >= :day_start AND created_at < :day_end
GROUP BY 1, 2, 3, 4
ON CONFLICT (date, country_code, source_name, is_logged_in)
DO UPDATE SET count = excluded.count;
```

Properties:

- **One pass over yesterday's events** populates every dashboard card's data.
- **Idempotent.** Re-runnable any number of times for any day within event retention. Used for backfill, parser changes, bug fixes.
- **No drift.** Every aggregate row's `count` equals `COUNT(*)` of the same source query. The dashboard's cards always reconcile to the same totals because they're all reads of the same underlying table.

### Today's partial-day data

The nightly rollup writes yesterday and earlier. Today is partial. Two options, decision deferred:

**A. UNION raw events for today.** Dashboard query reads aggregates for past days, raw events for today, in a `UNION ALL`. Always-fresh data, no scheduled work, slightly more SQL.

**B. Incremental rollup every 5 minutes.** A scheduled job re-aggregates today from start-of-day with `ON CONFLICT DO UPDATE` (full replace, idempotent). Single read source for the dashboard, freshness lags ≤ 5 min. Adds a job but simplifies the dashboard query.

Both are valid. We'll pick during implementation based on whether other features will also want today's aggregate rows.

### Crawler series

Crawler pageviews aren't in `browser_pageview_events` (crawlers don't fire JS). The chart's Crawlers filter pill reads from the existing `application_requests` table (`req_type = page_view_crawler`).

This is the one place the new section reads from the legacy table. Acceptable because the read is decoupled (the legacy table is not modified) and crawler-by-country/by-referrer is not in scope.

## Referrer parsing

Done at rollup time so changes to parser rules can rewrite history within retention.

- **Vendor or fork** `github.com/snowplow-referer-parser/ruby-referer-parser` (Ruby gem `referer-parser`). The canonical Ruby implementation is functional but appears unreleased; we'd own its lifecycle.
- **Pull `referers-latest.yaml`** from Snowplow's S3 weekly via a scheduled job. The YAML is the valuable artifact and is updated daily upstream.
- **Add `custom_sources.yaml`** in core, version-controlled, for Discourse-specific overrides the upstream YAML doesn't cover.
- The parser returns `{ source, medium, term }`. We use `source` for the `source_name` column. `medium` (search/social/email) is captured for the future GA4-style "Channels" rollup if/when that's needed.

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

- Headline pageview total, logged-in share KPI, chart with daily/monthly bucketing, filter pills — all from `pageview_daily_aggregates` + `application_requests` (crawler series).

### v1 deferred / v2

- **Top countries card**, **top referrers card** (source level), **referrer drill-down** (host+path level via separate summary table) — all derivable from the same Tier 1 events; new aggregates added as needed.

### v3+ (architecturally enabled, not committed)

- **Unique visitors KPI** via HyperLogLog sketches on `session_id` (requires `hll` extension; available on RDS, optional for self-hosted).
- **Session duration / bounce rate** via window functions over Tier 1 events at rollup time. No write-path changes needed.
- **GA4-style "Channels" rollup** (Search/Social/Direct/Referral/Email/etc.) using `medium` from the referrer parser.
- **Ad-hoc admin investigation** ("what did this user view?", "where did the May 7 spike come from?") via direct queries on Tier 1 within retention.

## Open questions for implementation

1. **Today's partial-day reads.** 5-minute rollup (option B) or `UNION ALL` with raw events (option A) — pick during implementation.
2. **Path-level drill-down summary table.** Schema, top-N parameter, "Other" bucket label — design when the top-referrers card is scoped.
3. **`pg_partman` for `browser_pageview_events`.** If retention windows or growth rate justify it. Available on RDS; would need to bake into the official self-hosted Docker image. Not required for v1; defer.
4. **`hll` extension** for unique-visitor metrics. Optional; feature degrades to "exact distinct on small windows" if extension absent.
5. **Default retention values.** Confirm the 30-day IP / 6-month row / indefinite aggregate defaults with security review.
6. **Referrer parser packaging.** Vendor `referer-parser` gem, fork it, or rewrite as a thin Ruby parser over the YAML — pick during implementation.

## Non-goals for v1 of this data layer

- City-level geolocation. Country only.
- Per-event UTM tag parsing. Captured in `referrer` raw URL; not surfaced.
- Real-time streaming dashboards. Daily granularity, sub-second freshness via 5-min rollup at most.
- Cross-site analytics across multisite installations. Each site's data stays in its own scope.
- Webhooks or external streaming of pageview events. Internal-only data path.
