# Site Traffic chart — rendering notes

This document captures the lessons learned during the spike around why
extending `AdminReportStackedChart` for the new Site Traffic section turned
into repeated bandaging, and why we ended up bypassing it entirely. **Read
this before deciding to route the v1 implementation through the shared
stacked chart.**

## TL;DR

The site-traffic spec asks for a bar chart with **opaque, equally-spaced
buckets** labelled in **UTC**. Every "make it match the spec" attempt that
went through `AdminReportStackedChart` fought one or more of the following:

1. The shared chart hardcodes `type: "time"`, which forces Chart.js's
   moment adapter to parse data x-strings as **local-TZ** timestamps.
2. `Report.collapse` (the legacy bucketing helper) ALSO parses dates as
   local-TZ moment values to compute week/month boundaries.
3. The site-traffic spec wants UTC labels, so our label callbacks format
   in UTC.

Three independent timezone interpretations of the same date string. Bars
are positioned at one offset, ticks at another, labels formatted to a
third. Whatever you fix in one place re-breaks the next.

The clean answer for site traffic was: **don't use a time scale, don't use
`Report.collapse`, and don't extend the shared component**. Render an
inline category-axis chart with our own UTC-aware aggregator.

## What the spec actually needs

- N stacked bars, one per bucket (day / week / month).
- Equal pixel spacing — read as a sequence of buckets, not a continuous
  timeline.
- Labels under their bars in **UTC**.
- First/last labels always present; intermediate density is automatic.
- Each bar's label = the first day of data in that bucket (period start
  for the leftmost partial week).
- Tooltip title derived from `bucket.start` / `bucket.end`, the same data
  the bar actually contains.

None of this needs `time` axis features. Time scales pay off when you
have **irregular timestamps** (e.g., per-event scatter) where Chart.js's
date math saves you from positioning bars manually. We always have one
data point per bucket and want them equispaced — `category` is the right
primitive.

## Why `type: "time"` was the wrong primitive for us

Chart.js's time scale + `chartjs-adapter-moment` parses anything passed in
as `moment(value)` — which uses **local time** by default. Our data x's
look like `"2026-05-07"`, parsed as local midnight. For a Singapore (UTC+8)
viewer that maps to `2026-05-06T16:00:00Z`. Our UTC label callback then
formats the timestamp as `"6 May"`. Off by one for every viewer not in
UTC.

Workarounds we tried, each adding a new option flag and each leaving the
next problem visible:

| Bandage | Symptom it fixed | What it broke / didn't fix |
|---|---|---|
| `xMaxTicksLimit` + `autoSkip` | Density of intermediate labels | Last bar's label dropped (autoSkip ignores `major: true`). |
| `xPinFirstLastTicks` (custom `afterBuildTicks` curator) | Last/first label dropping | Months still visually unevenly spaced (Feb=28d, Jul=31d). |
| `xMax` + `bounds: "ticks"` | Rightmost bar half-clipped | Cumulative — no resolution to the TZ-shift. |
| `xOffset: true` | Chart.js tight-fit cropping | Bars positioned at parsed-local-midnight ms, ticks at the same ms. Offset works, but the underlying TZ shift remains. |
| `utcDataPoints: true` (convert all x to UTC ms before handing to Chart.js) | TZ shift on bar positions | Bars now at UTC-midnight ms, but Chart.js's auto-generated ticks (and tooltip x parsing) are still local. Need afterBuildTicks to override. |
| `tooltipFooterCallback` | "Total" mixing humans + crawlers | Just a passthrough; not a TZ fix. |
| `showEmptyTooltip` | Hover on zero days hid tooltip | Just a passthrough. |
| `tooltipTitleCallback`, `xTicksCallback`, `xTickColorCallback` | Format dates in UTC | The formatting was correct — but the underlying ms timestamps were off, so labels still drifted. |

After ~8 flags, the chart still:

- Misaligned bars and labels by half-bar widths in some periods.
- Dropped the last x-axis label on Last 30 days (Chart.js's autoSkip
  doesn't reliably honour `major` on time-scale ticks).
- Showed "Apr 2026" for the May bucket on Last 12 months in TZs east of
  UTC, because `Report.collapse` bucketed by local-month and our UTC
  formatter then read the bucket-start ms as the previous UTC day.

Each fix lifted one problem and exposed the next.

## Why `Report.collapse` made it harder, not easier

`Report.collapse(model, data, grouping)` is the legacy helper that
aggregates daily data into weekly/monthly buckets. It iterates the data
calling `moment(d.x, "YYYY-MM-DD")` (local TZ) and groups by
`startOf("isoWeek")` / `startOf("month")` in local time. The **bucket
start key** it emits is `currentStart.format("YYYY-MM-DD")` of a
local-time moment.

For Singapore (UTC+8) and a daily series ending May 7, 2026:

- `moment("2026-05-07")` → local May 7 midnight = UTC May 6 16:00.
- `currentStart.startOf("month")` → local May 1 midnight = UTC Apr 30 16:00.
- `format("YYYY-MM-DD")` → `"2026-05-01"`.

So far the **string** is correct. The trap is downstream: we passed
`"2026-05-01"` to Chart.js's time scale, which re-parsed it via the
moment adapter as local May 1 = UTC Apr 30 16:00. Our UTC label
callback then formatted that ms as **`"Apr 2026"`**. Two correct
local-TZ operations + one UTC formatter = wrong label.

The legacy helper is not buggy in isolation — every consumer prior to
site traffic agreed on local-TZ rendering, so the round-trip was
consistent. But site traffic wants UTC, so we'd have to either:

- Replace `Report.collapse` for our path (we did; it's a one-screen
  function); OR
- Override its output with a UTC re-anchor (we tried; the workaround
  was bigger than the helper itself).

## What "the right shape" looks like

Server returns **one row per UTC day** per series:

```json
{
  "data": [
    { "req": "page_view_logged_in_browser",
      "data": [
        { "x": "2026-05-01", "y": 1629 },
        { "x": "2026-05-02", "y": 1629 },
        ...
      ]
    },
    ...
  ]
}
```

`x` is an opaque date string. We never need to parse it for **bar
positioning** — bars are positioned by index in a category axis. We only
parse it once, when **formatting** the tick label or tooltip title, and
that single parse is `moment.utc(x, "YYYY-MM-DD")`.

A ~15-line aggregator owns bucketing in UTC:

```js
function bucketize(seriesData, bucketing) {
  if (bucketing === "daily") {
    return seriesData.map(d => ({ start: d.x, end: d.x, total: d.y }));
  }
  const buckets = new Map();
  for (const d of seriesData) {
    const groupKey = bucketing === "weekly"
      ? moment.utc(d.x, "YYYY-MM-DD").startOf("isoWeek").format("YYYY-MM-DD")
      : `${d.x.substring(0, 7)}-01`;
    const existing = buckets.get(groupKey);
    if (existing) {
      existing.total += d.y;
      existing.end = d.x;
    } else {
      buckets.set(groupKey, { start: d.x, end: d.x, total: d.y });
    }
  }
  return Array.from(buckets.values());
}
```

The chart options collapse to ~50 lines: a `category` x-axis, a `linear`
y-axis with our round-step picker, a `tooltip` block with two callbacks,
and `minBarLength: 3` on each dataset.

## Lessons for the v1 implementation

1. **Don't put the v1 chart through `AdminReportStackedChart`.** The
   shared component is fine for legacy reports that want a time scale +
   local-TZ rendering; the option-flag interface is fine for those use
   cases. For site traffic specifically, the requirements are different
   enough that mixing them is the source of bugs.

2. **Don't use `Report.collapse` for site-traffic bucketing.** Write
   the aggregator inline. The bucketize function is shorter than the
   workaround code we'd need to make `Report.collapse`'s local-TZ output
   match a UTC label.

3. **Don't use a `time` scale.** Use `category`. Bars at integer indexes,
   equal slot widths, no irregular month spacing, no TZ math.

4. **Treat the data x-string as opaque** through aggregation. Parse it
   exactly once, at label render time, with `moment.utc`.

5. **Single source of truth per concept.** The bucket's `start` is the
   first day of actual data; the bucket's `end` is the last day. Both
   x-axis label and tooltip title derive from those. There is no
   "theoretical Mon–Sun" stored anywhere alongside, so they can never
   drift.

6. **One place for the chart config.** `chartConfig` lives in the
   section component. No flag-based extension points in shared code.
   When something needs to change (the trend phrase, the tooltip footer,
   the y-axis formatter), find and edit it in one file.

## When *would* it be right to extend `AdminReportStackedChart`?

- Another admin report wants the same generic stacked-chart behaviour
  (time scale, local-TZ rendering, single Total in the tooltip footer).
  Add it as a consumer with the existing API.

- A change is **strictly additive** and has no effect on other reports
  (e.g., a new accessibility attribute on legend buttons).

If your change is a flag whose only consumer is going to be site traffic,
it doesn't belong there — put it in the site-traffic component.
