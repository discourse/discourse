# Site Traffic Headline Design History

> Working note for resuming the Site Traffic headline design conversation. This is not a product spec and should not replace the objectives document. It records the design iterations, reversals, and rationale from the prototype conversation.

## Related files

- `site-traffic-implementation-objectives.md`
- `site-traffic-chart-rendering-notes.md`
- `public/site-traffic-headline-prototypes.html`

## Scope of this note

This conversation focused on the headline summary area in the new Site Traffic section, especially the text pattern around:

- pageview count
- selected period descriptor
- trend direction and delta
- what comparison period the trend is relative to

The work also broadened into how to review those headline options in context:

- with the KPI
- with the filter pills
- with a chart visible underneath
- across all period states and both light/dark themes

## Current prototype state

The current prototype is:

- `public/site-traffic-headline-prototypes.html`

Current structure:

- Three tabs: `Option A`, `Option B`, `Option C`
- No explanatory header or intro content above the options
- Each tab shows the option across:
  - `Last 7 days`
  - `Last 30 days`
  - `Last 90 days`
  - `Last 12 months`
  - `Custom range`
- Each period is shown across:
  - positive trend
  - negative trend
  - small positive delta (`up 0.3%`)
  - no comparison
  - zero pageviews
- Each state is shown in separate light and dark rows
- Each preview includes:
  - section heading
  - headline treatment
  - filter pills
  - compact chart mock

## High-level design direction

The conversation converged on the idea that the main problem is not color or badge shape first. The main problem is that a phrase like `up 0.3%` is ambiguous unless the comparison basis is obvious.

The user repeatedly pushed for:

- less ambiguity around what the trend is compared to
- less clutter in the headline itself
- less forced scanning through toggles and hidden states
- review in realistic card context, not headline-only fragments

## Iteration history

### 1. Initial exploration

The work started by reading the objectives and current branch work, then creating a standalone HTML prototype in `public/` that matched the branch styling closely enough to evaluate headline copy.

The first prototype explored four headline patterns:

- `Option A`: current-branch-style baseline
- `Option B`: balanced inline trend coloring
- `Option C`: trend badge treatment
- `Option D`: split count and metadata treatment

At this stage, the prototype also exposed:

- period selector controls
- scenario controls
- theme toggle

## 2. Ambiguity in `up 0.3%`

The first major design issue raised was:

- `up 0.3%` compared to what?

That shifted the conversation from pure visual treatment into information architecture. The trend could not stay as a detached signal. It had to reveal its comparison basis somewhere close to the number.

This led to explicit exploration of comparison wording.

## 3. Show all states at once

The next usability issue raised was that toggling through periods, scenarios, and themes made review too slow.

The prototype was changed to show all states up front instead of requiring:

- period toggles
- scenario toggles
- theme toggle

The first version of this showed large state boards with many cards visible at once.

## 4. Light/dark visibility changes

The first all-states board still made theme comparison harder than it needed to be. Light and dark were initially arranged side by side in a way that still encouraged horizontal scanning.

That led to a redesign where:

- light and dark were rendered as separate rows for each state
- no theme toggle was required

This made theme comparison more explicit and reduced review friction.

## 5. Caret removed from Option C

The user called out the caret in Option C as something they were not feeling.

That led to a change from:

- a caret or arrow-like directional glyph

to:

- a word-only pill such as `up 0.3%` or `down 12%`

Reasoning:

- the word already communicates direction
- the color and pill shape already provide a visual cue
- the caret added chart-like noise without adding much meaning

## 6. Comparison basis moved below the headline

The next refinement was to avoid overloading the main headline line.

Option C was changed so that:

- the headline remained the count plus period descriptor
- the trend pill and comparison basis moved to a second line below the headline

This was an intentional compromise:

- keep the first line clean
- keep the comparison basis near the trend
- avoid burying the explanation in a tooltip

## 7. Comparison wording experiments

Several comparison phrasings were explored for Option C.

Rejected or de-emphasized wording:

- `vs previous 7 days`
  - felt conflicting next to `in the last 7 days`
- `over the prior 7-day period`
  - clearer, but too wordy for this card
- `compared to prior period`
  - readable, but long

Shorter candidate families that were explored:

- `vs prior period`
- `vs prior 7 days`
- `vs 25 Apr - 1 May`
- `vs prior period, Apr 25 - May 1`

## 8. Recommended phrasing during the conversation

The strongest text recommendation during the conversation was:

- `up 9%` pill + `vs prior period, Apr 25 - May 1`

Why this was preferred:

- `prior period` explains the comparison model
- the dates remove ambiguity
- the text stays shorter than a fully spelled-out sentence
- it avoids the awkward `last 7 days` versus `previous 7 days` pairing

## 9. Option D removed

At one point the user asked to scrap Option D completely.

That led to removal of:

- the `Option D` entry from the prototype
- the split recommendation comparison card
- caret-dependent split-specific helper code

From that point onward the prototype focused only on:

- `Option A`
- `Option B`
- `Option C`

## 10. Tabs instead of one giant page

Even after removing toggles for state visibility, the full page still contained a lot of content. The prototype was then changed again to simplify review:

- replace the big all-options page with three tabs
- one tab for each option: `Option A`, `Option B`, `Option C`
- remove the contextual explanatory content above the options

This made the page feel more like a focused review surface than a design essay.

## 11. Chart restored for context

After the tabs simplification, the user asked to include the chart again so the headline would be evaluated in realistic context.

That led to reintroducing a compact chart mock into each preview card:

- period-specific bar counts
- scenario-specific traffic shape
- filter pills still visible
- zero-state overlay still visible

This matters because the headline does not live in isolation. The headline, KPI, pills, and chart need to feel like one coherent section.

## Option-by-option summary

### Option A

Intent:

- closest to the current branch style

Traits:

- single-line headline
- minimal extra framing
- trend remains compact

Weakness:

- trend comparison basis is still not explicit enough

### Option B

Intent:

- explicit inline comparison in the headline line

Traits:

- most direct wording
- no ambiguity when fully written

Weakness:

- headline becomes long quickly
- wraps earlier
- can feel too report-like

### Option C

Intent:

- keep the first line clean
- move the comparison unit to a compact second line

Traits:

- word-only trend pill
- comparison text immediately adjacent to the pill
- current preferred family of wording is:
  - `vs prior period, <date range>`

Why it survived:

- balances clarity and compactness better than A or B
- keeps the headline readable
- avoids the caret

## Design considerations that kept recurring

### Clarity beats novelty

The conversation repeatedly favored text that explains the comparison model over visual cleverness.

### The comparison basis must be local

The trend should not rely on:

- a tooltip
- product knowledge
- invisible assumptions about analytics conventions

### The first line should stay calm

The pageview count and selected period already carry a lot of weight. Once the trend and comparison text get too long, the headline starts feeling like a sentence instead of a summary.

### Review surface matters

The user did not want to review this by toggling:

- period
- scenario
- theme

The review flow had to expose the states directly.

### Context matters

The headline should be judged with:

- the KPI
- the filter pills
- the chart

not as an isolated line of copy.

## Open questions

These are the most useful questions to resume from:

1. For Option C, is `vs prior period, Apr 25 - May 1` the right balance, or is there a shorter label that still feels unambiguous?
2. Should the date formatting in the comparison text vary by range length?
3. Should monthly comparisons use a month-only label rather than full dates when the comparison spans a full year window?
4. Is the second-line comparison treatment strong enough visually, or should the baseline text be slightly more prominent relative to the pill?
5. Should the chart mock in the prototype remain compact, or should a larger version exist for more realistic review?

## Resume checklist

If this conversation is resumed later, start here:

1. Open `public/site-traffic-headline-prototypes.html`
2. Review the current `Option C` treatment first
3. Compare whether the second-line baseline should stay as:
   - `vs prior period, <date range>`
4. Decide whether the dates should remain abbreviated or become more explicit
5. Only after the wording settles, revisit finer typography or spacing changes

## Notes on source of truth

- Product behavior and scope belong in `site-traffic-implementation-objectives.md`
- Chart-specific technical/design notes belong in `site-traffic-chart-rendering-notes.md`
- This file is specifically for preserving the headline-design conversation history and rationale
