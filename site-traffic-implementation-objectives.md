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

**Out of v1 (deferred):**

- "See details" drill-down to the existing Site Traffic report — deferred because the legacy report looks visually different and behaves differently from the redesigned section (different filters, different bucketing, different x-axis style), so a one-click handoff would feel like a context break rather than a continuation. Revisit once the legacy report is reskinned, or once we know what extra detail admins want and can build a dedicated drill-down view.
- AI-generated insights paragraph
- Traffic spike callout
- Average session KPI
- Bounce rate KPI
- Top referrers card
- Top countries card

**Visibility:** the section appears only when the dashboard improvements feature is on. With it off, the existing admin dashboard is unchanged.

**Pageview-tracking modes:** the section works on both the modern browser-based pageview-tracking model (default for new sites) **and** the legacy pageview-tracking model (`use_legacy_pageviews = true`). The headline, KPI, and chart series are sourced from whichever counters the site is actively collecting — modern sites use the browser-detected `page_view_logged_in_browser` / `page_view_anon_browser` counters, legacy sites use the older `page_view_logged_in` / `page_view_anon` counters. The crawler series uses the same counter in both modes. Crawler/anon/logged-in semantics are slightly different between the two models (the legacy counters can include some bot traffic that the browser-detected counters filter out), but the **product behavior** of the section is the same: humans + crawlers split, headline = humans only, KPI = logged-in share of humans.

## Layout

A single section card. Top-down: section heading → headline + KPI row → filter pills → chart. On private communities, the headline expands full-width since the KPI is hidden. The section is responsive: elements stack on narrow viewports.

The Top referrers and Top countries cards show each row's share first, followed by the pageview count in brackets, e.g., `42% (12.3k)`.

## Section heading text

The section is titled "Site traffic", rendered in a section-header style.

---

## Key concepts

These define what numbers mean across the section. They are referenced by the objectives below.

- **Pageview total** is the count of *human* pageviews — logged-in members and anonymous visitors. Crawler traffic is **not** counted in the headline number; it's shown separately in the chart for context.
- **On private communities**, the pageview total is logged-in pageviews only. (Anonymous and crawler traffic on a private site is incidental — login-page hits and similar — and is excluded.)
- **The logged-in share KPI** is the percentage of human pageviews that came from logged-in members. It excludes crawlers by definition; it's about people, not bots.
- **Date range behavior comes from `db-date-range`.** Site Traffic does not define its own preset boundaries, timezone handling, or custom-range picker behavior. It consumes the start and end dates produced by the shared redesigned-dashboard date range control.
- **Period presets**:
  - Last 7 days = the shared `db-date-range` Last 7 days preset.
  - Last 30 days = the shared `db-date-range` Last 30 days preset.
  - Last 3 months = the shared `db-date-range` Last 3 months preset.
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

### 1b. Date inputs

Date input behavior is owned by the shared dashboard date range control and the dashboard controller.

1b.1 Site Traffic does not add its own date validation UI.

1b.2 Direct requests to the Site Traffic report still use the report endpoint's normal request validation and authorization.

1b.3 If `db-date-range` behavior changes, Site Traffic follows that behavior without a section-specific override.

### 2. Section header

2.1 The section displays "Site traffic" as a section header.

2.2 The heading text is translatable.

2.3 The section's outer chrome — frame, border, header row, content padding, and inter-row spacing — is delegated to the shared `Dashboard::Section` component (introduced in #39841) so the section reads visually identical to the other dashboard sections (Highlights, Reports, Engagement). Site Traffic only owns the body content (headline, KPI, filter pills, chart). Future refinements to the section frame (e.g., header action slot, expand/collapse, drag-to-reorder) come from `Dashboard::Section` rather than being reimplemented here.

### 3. Dashboard date range

3.1 Site Traffic does **not** render its own date selector. It relies on the dashboard-level `db-date-range` control shared by the redesigned dashboard.

3.2 The dashboard-level selector applies to everything in the section: headline, KPI, and chart all reflect the selected period.

3.3 Admins choose between the periods supported by `db-date-range`: **Last 7 days**, **Last 30 days**, **Last 3 months**, or a **Custom range**.

3.4 First load defaults to **Last 30 days**.

3.5 All period labels are translatable through the shared dashboard date-range component.

3.6 Custom range opens the shared dashboard date-range picker.

3.7 Switching periods updates all dependent UI together. **The chart's x-axis range and bucketing stay anchored to the currently displayed data until the new fetch lands** — admins do not see the chart's date range expand, contract, or re-bucket ahead of the new bars. The transition is atomic: when new data arrives, the axis range, bucketing, headline, KPI, and bars all swap to the new period together.

3.8 **Rapid changes show the latest selection.** When admins cycle quickly through periods, the data displayed always reflects their most recent choice — slower in-flight responses for older selections never overwrite newer ones.

3.9 Boundary edge cases — midnight, daylight saving transitions, leap days — follow the shared `db-date-range` behavior.

### 4. Headline summary

4.1 The headline shows the pageview total for the selected period.

4.2 The headline matches the human-traffic portion of the chart bars exactly. (Crawler bars may render in addition; they don't affect the headline number.)

4.3 **Headline format**: `<count> pageviews <period descriptor> — <up|down> <delta>% (?)` (e.g., "712k pageviews in the last 30 days — up 9% (?)"). Counts use locale-aware abbreviations (e.g., 712k, 1.2M). The `(?)` is a question-mark info icon rendered immediately after the trend phrase; it reveals a tooltip naming the comparison period on hover or keyboard focus (§4.4c). The headline copy itself stays compact and does **not** include the comparison basis inline — the tooltip carries that detail so the line reads cleanly when scanning the dashboard.

4.4 The trend phrase is included when a meaningful comparison can be made and is omitted when:
- The prior period extends before pageview tracking began (see **Trend coverage** in Key concepts).
- Both the current and prior periods have zero pageviews.
- Current and prior values are equal, or differ by less than 0.05% (a "0%" or "0.0%" trend would be visual noise).
- The prior period had zero pageviews and the current has some (a "new" or arbitrary trend would mislead).

When the trend phrase is omitted, the headline stops after the period descriptor. It should not render a dash, placeholder, "no change", "no comparison", or muted explanatory copy in Option A. Examples:

- "0 pageviews in the last 7 days"
- "712k pageviews in the last 30 days"
- "4.2M pageviews in the selected period"

4.4a **Trend precision**: when `|delta|` is at least 1%, the trend shows an integer percent (e.g., "up 9%", "down 12%"). When `|delta|` is less than 1% but at least 0.05%, the trend shows one decimal place (e.g., "up 0.3%", "down 0.7%") so admins still see a meaningful indicator on quiet periods.

4.4c **Comparison-period info icon.** A small Font Awesome `far-circle-question` (outline question mark) icon renders immediately after the trend phrase whenever the trend phrase is shown. The icon is rendered in the muted axis-label color and slightly smaller than body text so it doesn't compete with the headline copy. Hovering or keyboard-focusing the icon reveals a tooltip that names the prior period the trend is being compared against and includes the comparison duration — e.g., `Compared with the previous 30 days (Mar 10 – Apr 8, 2026)` for a Last 30 days view on May 8, 2026. The tooltip uses Discourse's existing `DTooltip` component for parity with other info-icon tooltips in the admin UI. When the trend phrase is omitted (per §4.4) the icon is omitted too — there is nothing to compare. The tooltip text is translatable; the date range follows the date range returned by the report and uses cross-year formatting only when the prior period spans calendar years.

For `db-date-range` presets, the tooltip duration mirrors the selected preset: `previous 7 days`, `previous 30 days`, or `previous 3 months`. For custom ranges, the duration is the exact inclusive day count of the selected range: a one-day custom range reads `Compared with the previous day (...)`; multi-day custom ranges read `Compared with the previous N days (...)`.

4.5 When the prior period had pageviews and the current has zero, the trend reads "down 100%".

4.6 Trend color in Option A:

- Positive trend phrase (`up <delta>%`) is green/success colored.
- Negative trend phrase (`down <delta>%`) is red/danger colored.
- The pageview count and period descriptor remain the normal headline text color.
- Colors must be theme-aware and meet accessibility contrast standards in both light and dark mode.

4.6a The dash between the period descriptor and trend phrase is neutral text color, not trend-colored. Only the words and percentage in the trend phrase carry the trend color.

4.7 The headline is shown on both public and private communities.

### 5. Logged-in share KPI

5.1 On a **public community**, the logged-in share KPI is visible alongside the headline.

5.2 On a **private community**, the KPI is hidden (logged-in share would always be ~100%, offering no signal). The headline expands to use the freed space.

5.3 The KPI shows the share of human pageviews that came from logged-in members, as an integer percentage.

5.4 When the period has no human pageviews, the KPI reads `0%`.

5.5 The KPI label reads "Logged-in share".

5.6 An info icon next to the label opens an explanatory tooltip on hover. The icon is the same `far-circle-question` (outline question mark) used for the trend's comparison-period tooltip (§4.4c) so all info icons in the section read as one family.

5.7 The KPI does not show a period-over-period trend in v1.

### 6. Filter pills

6.1 On public communities, three filter pills sit between the KPI row and the chart: **Logged in**, **Anonymous**, **Crawlers**. Each has a colored swatch matching its chart series.

6.2 On first load, Logged in and Anonymous are selected; Crawlers is **off**, so the initial chart shows only human traffic. Admins opt into crawler traffic by clicking its pill.

6.3 Clicking a pill toggles whether its series is shown in the chart. Toggling is instant — no waiting for the server.

6.3a **Alt-click to solo a filter**: alt-clicking (Option-click on macOS) a filter pill activates only that pill and deactivates the others — a "solo" view of one series. Alt-clicking the soloed pill again restores all filters to active. This matches the common solo-toggle convention in analytics dashboards (e.g., Grafana, Datadog). The basic-click behavior in §6.3 is unchanged.

6.4 At least one pill must remain selected. Admins cannot turn off the last active filter (the chart is never empty by user choice).

6.5 **Inactive pills are visually distinguishable from active ones via a swatch-color treatment** — for example, a hollow outline of the series color rather than a filled swatch — *not* via a strikethrough or other text decoration on the label. This rule ensures the inactive state is recognizable across all swatch colors, including very light ones.

6.6 On private communities, no filter pills are shown (only logged-in traffic exists).

6.7 Pills have a clear pressed/unpressed state.

6.8 Pill labels are translatable.

### 7. Pageviews chart

7.1 The chart shows pageview trends as stacked bars over the selected period.

7.2 Bars are aggregated based on the period's length, so the chart stays readable at any range:
- **Up to one month (≤ 31 days)**: one bar per day. Covers the Last 7 days and Last 30 days presets and short custom ranges.
- **More than one month, less than one year (32–364 days)**: one bar per week. Covers the Last 3 months preset and equivalent custom ranges. **Weeks always run Monday → Sunday** regardless of the viewer's locale week-start preference, so admins on different locales see consistent week boundaries. The x-axis label for each weekly bar is the bucket's start date (the Monday) and sits centered under the bar.
- **One year or more (≥ 365 days)**: one bar per month. Covers longer custom ranges.

The same rules apply to preset and custom periods of equivalent length.

**Every day in the selected period is represented in the chart**, even if no pageview data exists for that day. Missing-data days are filled in as zero values rather than skipped — so the x-axis spacing stays uniform, daily slots are never collapsed, and partial weeks/months at the start or end of the period still render their bars with whatever data they have.

**This is a server-side guarantee**: the API endpoint returns one entry per day in the selected period, regardless of whether the underlying request log has rows for those days. Days with no recorded data return zero counts. The frontend can rely on the response being complete and does not need to fill gaps client-side.

7.3 On public communities, bars stack: Logged in at the bottom, Anonymous in the middle, Crawlers on top. Each color matches its filter pill.

7.4 On private communities, only the Logged in series renders.

7.5 **X-axis labels stay readable across all periods**:
- The label format is appropriate to the bucket type: a day + month for daily and weekly bucketing (the weekly label is the **first day of data in that bucket** — bucket Monday for full weeks, period start for the leftmost partial week), a month name for monthly.
- **Unified year rule**: when a period spans calendar boundaries, **every** label includes the year (e.g., `22 Dec 2025`, `23 Dec 2025`, …, `1 Jan 2026`, …). When a period stays within one calendar year, no labels include the year (e.g., `8 Mar`, `15 Mar`). This produces a consistent axis format across the period — no asymmetric mix of short and long labels.
- **Monthly bucketing** always includes the year on every label, regardless of whether it spans years, since the year-or-longer scale at this bucket size almost always crosses calendar boundaries and the small label count leaves room for the extra characters.
- **Density is automatic, not pinned**: the chart picks how many labels fit at the current width rather than forcing every bar to be labeled. Even short ranges like Last 7 days and Last 30 days do not label every single bar — labels thin to a comfortable density. Cross-year daily ranges show fewer labels than same-year daily ranges of equal length because each cross-year label is wider.
- **The first and last bars are always labeled**, regardless of any density thinning that the chart engine applies in between. Even if the auto-density algorithm would normally skip them — e.g., because the labels would crowd the chart edges — the first and last positions are pinned so admins always see the start and end of their selection on the x-axis.

7.6 **Today's bucket is always rendered.** For preset periods (which always end today) and custom ranges that end today, today's bucket is always the rightmost bar in the chart and its x-axis label is always pinned, regardless of whether today has any recorded pageviews. The label format follows §7.5 for the bucket size in use (daily: today's day; weekly: that week's Monday; monthly: today's month + year). The label renders in the same color as every other label — admins identify "today" by it being the rightmost slot, not by visual styling.

7.6a **Zero is treated as a data point.** Every bucket renders with a minimum visible bar height — including today before any traffic has been counted, an empty day in a quiet period, and tiny buckets whose values would otherwise round to zero pixels at the current y-axis scale. Without this, low-value or zero-value buckets disappear into the chart background and admins lose confirmation that the slot is in range. The minimum height is enforced per stacked series, so the cue is consistent across daily, weekly, and monthly bucketing.

7.6b **Axis label visual style**: tick labels on both the X and Y axes are rendered in a **muted text tone** (theme-aware — readable in both light and dark mode but visibly lighter than body text) and a **smaller font size than body text**. The labels should recede visually so the chart bars and shape dominate.

7.7 **Y-axis labels are always round numbers.** Admins never see awkward intermediate steps like 164k or 327k. The axis steps clearly (0 / 200k / 400k / 600k / 800k, or 0 / 1M / 2M / 3M, etc.). Abbreviated labels never include decimal multipliers — the axis shows "1M", not "1.5M"; "200k", not "250k".

7.8 The Y-axis starts at 0.

7.9 Hovering or touching a bar shows a tooltip. The tooltip uses the chart engine's default layout (per-series rows with a total) — only the **title format** is customized, and it follows the title pattern from the design exploration in `public/site-traffic-grouping-designs.html`:

- Daily: weekday + date, e.g., "Tue, 5 May 2026".
- Weekly: an inclusive Monday–Sunday range, e.g., "27 Apr – 3 May 2026" (with year on both ends when the bucket straddles a year boundary).
- Monthly: month + year, e.g., "May 2026".

The title shape alone identifies the bucket size; no separate "Daily / Weekly / Monthly" label is needed in the tooltip.

7.10 The tooltip explicitly distinguishes "Pageviews" (humans) from "Crawlers", so admins see at a glance that the headline number doesn't include crawlers.

7.10a **Empty-day tooltip**: hovering a bar whose visible series all have a value of 0 (e.g., a day or week with no recorded pageviews — including today before any traffic has been counted) still shows the tooltip with "0" values for each visible series and a "Total: 0". Admins can confirm a day or bucket is genuinely zero rather than missing.

7.10b **Each bar describes its actual data span.** The bar's x-axis label and tooltip both anchor to the **first day of data in that bucket** — bucket Monday for full weeks, period start for the leftmost partial week, first-of-month for full months, period start for the leftmost partial month. The tooltip end is the **last day of data in the bucket** — bucket Sunday / last-of-month for full buckets, period end for the rightmost partial bucket. So x-axis label and tooltip start always agree, and the tooltip never projects beyond data we have. Examples for a weekly Last 3 months period starting Saturday Feb 7 and ending today (May 7): the leftmost bar's x-axis label is "7 Feb" and its tooltip reads "7 Feb – 8 Feb 2026"; the rightmost bar's label is "4 May" and its tooltip reads "4 May – 7 May 2026"; middle bars show the full bucket Monday → Sunday. When the data span reduces to a single day the tooltip shows that day alone. Monthly partial buckets keep the month + year title since clamping doesn't add information beyond what the title already implies.

### 8. Graph state handling

8.1 **Loading state — page-level slider plus immediate section dim**: the section reuses Discourse's existing **page loading slider** (the thin animated bar at the top of the page that Discourse uses during navigation, controlled by the `page_loading_indicator` site setting). When data is being fetched (period change, custom-range update, retry), the section triggers the page-level slider just like a navigation event would, so admins see a familiar "loading" affordance at the top of the page. In addition, the section card dims to a reduced opacity **immediately on click** so the admin gets explicit visual confirmation that their action was registered — there is no delay before the dim starts. When new data arrives, the card snaps back to full opacity and the slider completes its animation. Throughout the dim, the previous period's headline, KPI, filter pills, and chart stay visible (faded) so the admin sees the old context until the new data lands. The period selector stays outside the dim and remains interactive. Initial first load also triggers the slider and dims the (initially empty) card.

8.2 **Empty (no human pageviews in the period)**: the chart still renders its axes; an overlay reads "No traffic data for this period". The headline still reads "0 pageviews ...". Filter pills still render on public communities.

8.3 A period with zero human pageviews but some crawler traffic is **not** considered empty — the chart shows the crawler bars and the overlay does not appear.

8.4 **Brand-new community** (no tracked traffic yet): the empty state renders cleanly — no broken layout, no stuck spinner.

8.5 **Custom range entirely before tracking started**: the empty state renders cleanly.

8.6 **Error**: when fetching fails, the chart area shows an error state with a retry control. The section heading and period selector remain interactive.

8.7 **Period partially predates tracking**: the chart silently starts at the first available date. The headline suppresses the trend phrase if the prior period would extend before tracking began.

### 9. Drill-down — deferred

A "See details" link to the existing `/admin/reports/site_traffic` page was originally planned for v1. It is **deferred** because the legacy report renders with different bucketing, a different x-axis treatment, and a different filter model from the redesigned section, so jumping into it from this section would feel like a context break rather than a continuation. The section ships without a drill-down in v1; admins still reach the legacy report through the existing admin nav. Revisit once the legacy report is reskinned to match, or once we know which extra detail admins actually want and can design a dedicated drill-down view rather than reusing the legacy page as-is.

### 10. Responsiveness & accessibility

10.1 The section is usable at typical desktop widths without horizontal scroll.

10.2 On narrow viewports, controls stack vertically (KPI below headline, filter pills wrapping, chart resizing) and remain usable.

10.3 Chart, KPI tooltip, and filter pills meet WCAG AA contrast standards.

10.4 All visible text is translatable.

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
