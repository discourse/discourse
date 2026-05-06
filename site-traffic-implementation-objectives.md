# Site Traffic Section — v1 Objectives

> What the new Site Traffic section in the redesigned admin dashboard does for admins. This document describes the product behavior — what an admin sees, what they can do, and how the system reacts. Engineering details (specific libraries, file paths, algorithms) are deliberately out of scope; those belong in implementation plans and code.

## Context

Part of the broader admin dashboard redesign tracked at:
- https://dev.discourse.org/t/reporting-and-analytics-dashboard-redesign-site-traffic-section/182874
- https://dev.discourse.org/t/reporting-and-analytics-admin-dashboard-v1-designs/182735

## Design reference

The visual reference mockup used to lock layout, filter UI, and chart styling decisions:

![Site Traffic section design mockup](https://d2yiocohlqn27b.cloudfront.net/original/4X/4/2/b/42b8d51bee47bc9f54a2368f733e914331672e48.png)

Source: post #1 of the [Site Traffic section topic](https://dev.discourse.org/t/reporting-and-analytics-dashboard-redesign-site-traffic-section/182874).

> The mockup shows the **full** future design including elements deferred to later versions. v1 implements only the elements listed in **Scope** below; refer to the mockup for visual styling of in-scope elements only.

## Scope

**In v1:**

- Section heading
- Headline summary (pageview total + period-over-period trend)
- Logged-in share KPI (public communities only)
- Filter pills (Logged in / Anonymous / Crawlers — public communities only)
- Pageview chart with adaptive bucketing
- "See details" link to the existing Site Traffic report

**Out of v1 (deferred):**

- AI-generated insights paragraph
- Traffic spike callout
- Average session KPI
- Bounce rate KPI
- Top referrers card
- Top countries card

**Visibility:** the section appears only when the dashboard improvements feature is on. With it off, the existing admin dashboard is unchanged.

**Pageview-tracking modes:** the section works on both the modern browser-based pageview-tracking model (default for new sites) **and** the legacy pageview-tracking model (`use_legacy_pageviews = true`). The headline, KPI, and chart series are sourced from whichever counters the site is actively collecting — modern sites use the browser-detected `page_view_logged_in_browser` / `page_view_anon_browser` counters, legacy sites use the older `page_view_logged_in` / `page_view_anon` counters. The crawler series uses the same counter in both modes. Crawler/anon/logged-in semantics are slightly different between the two models (the legacy counters can include some bot traffic that the browser-detected counters filter out), but the **product behavior** of the section is the same: humans + crawlers split, headline = humans only, KPI = logged-in share of humans.

## Layout

A single section card. Top-down: section heading → headline + KPI row → filter pills → chart → drill-down link. On private communities, the headline expands full-width since the KPI is hidden. The section is responsive: elements stack on narrow viewports.

## Section heading text

The section is titled "Site traffic", rendered in a section-header style.

---

## Key concepts

These define what numbers mean across the section. They are referenced by the objectives below.

- **Pageview total** is the count of *human* pageviews — logged-in members and anonymous visitors. Crawler traffic is **not** counted in the headline number; it's shown separately in the chart for context.
- **On private communities**, the pageview total is logged-in pageviews only. (Anonymous and crawler traffic on a private site is incidental — login-page hits and similar — and is excluded.)
- **The logged-in share KPI** is the percentage of human pageviews that came from logged-in members. It excludes crawlers by definition; it's about people, not bots.
- **All dates use UTC for now.** Dates are inclusive on both ends. Today is included in any range that ends today, even though today's count is partial-by-design. This matches the legacy dashboard's behavior for preset periods (the legacy dashboard's preset boundaries are also computed in UTC) and how Discourse buckets pageview counts internally. Viewer-locale-aware date handling is a possible future iteration; for the v1 section, UTC keeps the new section consistent with the rest of the platform.
- **Period presets**:
  - Last 7 days = today and the 6 prior days (7 days total).
  - Last 30 days = today and the 29 prior days.
  - Last 90 days = today and the 89 prior days.
  - Last 12 months = today and the 364 prior days.
  - Custom range = whatever the admin picks.
- **Prior equivalent period** = the comparison window used to compute the headline's trend phrase ("up 9%" / "down 3%"). It's a window the same length as the current selection, immediately preceding it. Concretely, if today is May 6 and the admin selects "Last 30 days" (the window April 7 → May 6), the prior equivalent period is March 8 → April 6 — the 30 days that came before. The trend is `(current_total − prior_total) / prior_total` expressed as a percentage.
- **Period descriptors** are the human-readable phrases in the headline copy that name the time window — e.g., the "**in the last 30 days**" portion of *"712k pageviews in the last 30 days — up 9%"*. The section deliberately avoids calendar phrasing like "this month" or "this week", because rolling windows rarely line up with calendar boundaries. On May 6, "Last 30 days" spans April 7 → May 6 — across two calendar months, not "this month". Saying "this month" in the headline would be misleading; "in the last 30 days" describes the actual window.
- **Trend coverage**: a trend phrase is shown only when both the current period and the prior period are fully within the time window where pageview tracking has been collecting data. If the prior period extends before tracking began, the trend phrase is omitted entirely — comparing against missing data would mislead.

---

## Objectives

### 1. Section visibility

1.1 Admins see the Site Traffic section in the admin dashboard when the dashboard improvements feature is enabled.

1.2 When the feature is disabled, the legacy general tab and existing site traffic chart are unchanged. No part of the new section appears anywhere in admin.

### 1a. Authorization

The section's data is admin-only. Access is enforced wherever the data flows, not just at the UI.

1a.1 Anonymous (signed-out) visitors cannot retrieve site traffic data.

1a.2 Authenticated non-admin users — regular members, elevated trust levels, moderators without admin — cannot retrieve site traffic data.

1a.3 Hand-crafted requests with custom date parameters from non-admins are rejected the same way as any other unauthorized request.

1a.4 The same authorization checks apply whether the section is visible (feature on) or not (feature off).

### 1b. Date validation

Date inputs are sanity-checked everywhere admins can supply them — both in the date picker and on direct requests.

1b.1 Inverted ranges (start after end) are rejected with a clear message.

1b.2 End dates beyond today are rejected or clamped to today, consistently.

1b.3 Ranges longer than 5 years are rejected.

1b.4 Malformed date inputs are rejected with a clear message.

### 2. Section header

2.1 The section displays "Site traffic" as a section header.

2.2 The heading text is translatable.

### 3. Period selector

3.1 The selector applies to everything in the section: headline, KPI, chart, and drill-down link all reflect the selected period.

3.2 Admins choose between **Last 7 days**, **Last 30 days**, **Last 90 days**, **Last 12 months**, or a **Custom range**.

3.3 First load defaults to **Last 30 days**.

3.4 All period labels are translatable.

3.5 Custom range opens a date-range picker. The picker rejects inverted ranges and dates beyond today.

3.6 Switching periods updates all dependent UI together.

3.7 **Rapid changes show the latest selection.** When admins cycle quickly through periods, the data displayed always reflects their most recent choice — slower in-flight responses for older selections never overwrite newer ones.

3.8 Boundary edge cases — midnight UTC, daylight saving transitions in the viewer's locale, leap days — behave correctly.

### 4. Headline summary

4.1 The headline shows the pageview total for the selected period.

4.2 The headline matches the human-traffic portion of the chart bars exactly. (Crawler bars may render in addition; they don't affect the headline number.)

4.3 Format: `<count> pageviews <period descriptor> — <up|down> <delta>%` (e.g., "712k pageviews in the last 30 days — up 9%"). Counts use locale-aware abbreviations (e.g., 712k, 1.2M).

4.4 The trend phrase is included when a meaningful comparison can be made and is omitted when:
- The prior period extends before pageview tracking began (see **Trend coverage** in Key concepts).
- Both the current and prior periods have zero pageviews.
- Current and prior values are equal, or differ by less than 0.05% (a "0%" or "0.0%" trend would be visual noise).
- The prior period had zero pageviews and the current has some (a "new" or arbitrary trend would mislead).

4.4a **Trend precision**: when `|delta|` is at least 1%, the trend shows an integer percent (e.g., "up 9%", "down 12%"). When `|delta|` is less than 1% but at least 0.05%, the trend shows one decimal place (e.g., "up 0.3%", "down 0.7%") so admins still see a meaningful indicator on quiet periods.

4.5 When the prior period had pageviews and the current has zero, the trend reads "down 100%".

4.6 Negative trends are visually distinguishable from positive trends, with the cue meeting accessibility contrast standards.

4.7 The headline is shown on both public and private communities.

### 5. Logged-in share KPI

5.1 On a **public community**, the logged-in share KPI is visible alongside the headline.

5.2 On a **private community**, the KPI is hidden (logged-in share would always be ~100%, offering no signal). The headline expands to use the freed space.

5.3 The KPI shows the share of human pageviews that came from logged-in members, as an integer percentage.

5.4 When the period has no human pageviews, the KPI reads `0%`.

5.5 The KPI label reads "Logged-in share".

5.6 An info icon next to the label opens an explanatory tooltip on hover or focus. The tooltip is keyboard-accessible.

5.7 The KPI does not show a period-over-period trend in v1.

### 6. Filter pills

6.1 On public communities, three filter pills sit between the KPI row and the chart: **Logged in**, **Anonymous**, **Crawlers**. Each has a colored swatch matching its chart series.

6.2 On first load, Logged in and Anonymous are selected; Crawlers is **off**, so the initial chart shows only human traffic. Admins opt into crawler traffic by clicking its pill.

6.3 Clicking a pill toggles whether its series is shown in the chart. Toggling is instant — no waiting for the server.

6.3a **Alt-click to solo a filter**: alt-clicking (Option-click on macOS) a filter pill activates only that pill and deactivates the others — a "solo" view of one series. Alt-clicking the soloed pill again restores all filters to active. This matches the common solo-toggle convention in analytics dashboards (e.g., Grafana, Datadog). The basic-click behavior in §6.3 is unchanged.

6.4 At least one pill must remain selected. Admins cannot turn off the last active filter (the chart is never empty by user choice).

6.5 **Inactive pills are visually distinguishable from active ones via a swatch-color treatment** — for example, a hollow outline of the series color rather than a filled swatch — *not* via a strikethrough or other text decoration on the label. This rule ensures the inactive state is recognizable across all swatch colors, including very light ones.

6.6 On private communities, no filter pills are shown (only logged-in traffic exists).

6.7 Pills are keyboard-accessible: focusable, toggleable with Enter/Space, with a clear pressed/unpressed state.

6.8 Pill labels are translatable.

### 7. Pageviews chart

7.1 The chart shows pageview trends as stacked bars over the selected period.

7.2 Bars are aggregated based on the period's length, so the chart stays readable at any range:
- Up to about three months: one bar per day. This covers the Last 7 days, Last 30 days, and Last 90 days presets, plus custom ranges of comparable length. Daily bucketing preserves day-level resolution; admins can spot weekday patterns and individual spikes.
- About three to twelve months: one bar per week.
- A year or more: one bar per month.

The same rules apply to preset and custom periods of equivalent length.

7.3 On public communities, bars stack: Logged in at the bottom, Anonymous in the middle, Crawlers on top. Each color matches its filter pill.

7.4 On private communities, only the Logged in series renders.

7.5 **X-axis labels stay readable across all periods**:
- The label format is appropriate to the bucket type: a day + month for daily and weekly bucketing, a month name for monthly.
- **Unified year rule**: when a period spans calendar boundaries, **every** label includes the year (e.g., `22 Dec 2025`, `23 Dec 2025`, …, `1 Jan 2026`, …). When a period stays within one calendar year, no labels include the year (e.g., `8 Mar`, `15 Mar`). This produces a consistent axis format across the period — no asymmetric mix of short and long labels.
- **Monthly bucketing** always includes the year on every label, regardless of whether it spans years, since the year-or-longer scale at this bucket size almost always crosses calendar boundaries and the small label count (≤12 in the Last 12 months preset) leaves room for the extra characters.
- Label density adjusts to the bucket type and label width — cross-year daily ranges show fewer labels than same-year daily ranges of equal length, since each cross-year label is wider.
- The first and last visible bars are always labeled, so admins always see the start and end of their selection.

7.6 **Today indicator**: when the rightmost bar's bucket includes today, its X-axis label is rendered with reduced visual emphasis. This applies only to daily and weekly buckets, where the partial-day cue is meaningful. Monthly buckets have no indicator.

7.7 **Y-axis labels are always round numbers.** Admins never see awkward intermediate steps like 164k or 327k. The axis steps clearly (0 / 200k / 400k / 600k / 800k, or 0 / 1M / 2M / 3M, etc.). Abbreviated labels never include decimal multipliers — the axis shows "1M", not "1.5M"; "200k", not "250k".

7.8 The Y-axis starts at 0.

7.9 Hovering or touching a bar shows a tooltip containing:
- The bucket's date or date range, in a form appropriate to the bucket — a single date for daily, an inclusive range for weekly, a month name for monthly. Daily tooltips include the day of the week so admins can spot weekly patterns at a glance.
- A "(today, partial)" suffix on the rightmost daily or weekly bar when its bucket includes today.
- The bar's pageview total (humans only).
- A separate "Crawlers" line with the crawler count.
- A per-series human breakdown (logged-in, anonymous) on public communities.

7.10 The tooltip explicitly distinguishes "Pageviews" (humans) from "Crawlers", so admins see at a glance that the headline number doesn't include crawlers.

### 8. Graph state handling

8.1 **Loading state — page-level slider plus immediate section dim**: the section reuses Discourse's existing **page loading slider** (the thin animated bar at the top of the page that Discourse uses during navigation, controlled by the `page_loading_indicator` site setting). When data is being fetched (period change, custom-range update, retry), the section triggers the page-level slider just like a navigation event would, so admins see a familiar "loading" affordance at the top of the page. In addition, the section card dims to a reduced opacity **immediately on click** so the admin gets explicit visual confirmation that their action was registered — there is no delay before the dim starts. When new data arrives, the card snaps back to full opacity and the slider completes its animation. Throughout the dim, the previous period's headline, KPI, filter pills, and chart stay visible (faded) so the admin sees the old context until the new data lands. The period selector stays outside the dim and remains interactive. Initial first load also triggers the slider and dims the (initially empty) card.

8.2 **Empty (no human pageviews in the period)**: the chart still renders its axes; an overlay reads "No traffic data for this period". The headline still reads "0 pageviews ...". Filter pills still render on public communities.

8.3 A period with zero human pageviews but some crawler traffic is **not** considered empty — the chart shows the crawler bars and the overlay does not appear.

8.4 **Brand-new community** (no tracked traffic yet): the empty state renders cleanly — no broken layout, no stuck spinner.

8.5 **Custom range entirely before tracking started**: the empty state renders cleanly.

8.6 **Error**: when fetching fails, the chart area shows an error state with a retry control. The section heading and period selector remain interactive.

8.7 **Period partially predates tracking**: the chart silently starts at the first available date. The headline suppresses the trend phrase if the prior period would extend before tracking began.

### 9. Drill-down

9.1 Below the chart, a "See details" link opens the existing Site Traffic report, scoped to the same period as the section.

9.2 The link text is translatable.

### 10. Responsiveness & accessibility

10.1 The section is usable at typical desktop widths without horizontal scroll.

10.2 On narrow viewports, controls stack vertically (KPI below headline, filter pills wrapping, chart resizing) and remain usable.

10.3 Keyboard navigation follows the visual order: heading → period selector → filter pills → drill-down.

10.4 All interactive controls have visible focus states.

10.5 Chart, KPI tooltip, and filter pills meet WCAG AA contrast standards.

10.6 All visible text is translatable.

### 11. Responsiveness of interactions

11.1 Switching periods feels fast — the section returns selected and prior counts in a single fetch.

11.2 Toggling filter pills is instant — no server round-trip is needed.

11.3 Rapid period changes never show stale data — the section always reflects the most recent selection.

### 12. Existing dashboard regression

12.1 With the dashboard improvements feature off, the legacy admin dashboard renders the existing site traffic chart and continues to function as before.

12.2 Existing tests for the legacy dashboard continue to pass unchanged.

---

## Engineering contract (non-functional, must hold)

These are the few engineering choices that are part of the section's risk profile and rollback safety, called out so they aren't reinterpreted later.

- **Backend isolation**: the section's data is served independently from the legacy site traffic backend. The existing module's query, payload shape, and endpoint are not modified. This guarantees the legacy chart and any external consumer of the legacy report cannot regress because of changes in this section.
- **Server-side validation**: the date and authorization rules in §1a and §1b apply at the API layer too, not just in the UI. The UI's checks are conveniences for admins; the server is the authority.

---

## Future considerations

These are known limitations or improvements considered during design but explicitly deferred. They are not blockers for v1 but should be revisited.

### Locale-aware date order on x-axis labels

Today's x-axis label format reads naturally for Latin-script locales (en, fr, de, es, etc.) but uses a fixed day-then-month order. CJK locales (ja, ko, zh) prefer month-then-day order — for example, Japanese speakers expect "3月8日", not "8 3月".

**Why deferred**: acceptable for the prototype and initial v1 release in en-first markets. Revisit when CJK locale rollout is prioritized or when this treatment is rolled out to other admin reports.
