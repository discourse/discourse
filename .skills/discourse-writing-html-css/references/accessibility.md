# Accessibility reference

Companion to the accessibility rules in `SKILL.md`. The short, point-of-use rules stay inline
there — semantic/landmark markup, icon labels, focus (`:focus-visible`), motion
(`prefers-reduced-motion`), and "don't rely on color alone." This file holds the deeper
mechanics: screen-reader-only text, accessible names (`aria-label` vs `title`), announcing dynamic
changes via live regions, and the contrast / forced-colors detail.

## Screen-reader-only text — `.sr-only`

When text should exist for assistive tech but not show on screen — extra context, a label for
an icon-only region, a skip target — use the `.sr-only` utility (defined in
[`app/assets/stylesheets/common/foundation/helpers.scss`](../../../app/assets/stylesheets/common/foundation/helpers.scss)).
It positions the text off-screen and clips it to a 1px box while keeping it in the
accessibility tree.

Do **not** use `display: none` or `visibility: hidden` for this — both remove the element from
the accessibility tree, so screen readers never announce it. `.sr-only` is the only correct way
to hide-visually-but-keep-for-AT.

```hbs
<button type="button">
  {{dIcon "trash-can"}}
  <span class="sr-only">{{i18n "post.controls.delete"}}</span>
</button>
```

## Accessible names — `aria-label` vs `title`

Every interactive control needs an **accessible name**. A control with visible text already has
one. An icon-only control (see the `.sr-only` example above) does not, so you supply it — but
`aria-label` and `title` are not interchangeable.

The accessible-name priority a screen reader uses, simplified: visible label / `.sr-only` text →
`aria-label` → `title`. Prefer the earliest that fits.

**`aria-label`** — the right tool for naming an icon-only control. It is invisible and *replaces*
any visible content for assistive tech, so:

- Use it only when there is **no** visible text label (otherwise the visible text already names
  the control and a second name is redundant or conflicting).
- The value must be **translated** — pass an i18n string, never a hardcoded English literal.
- It works only on elements with a role (interactive elements, or something given `role="…"`). On
  a bare `<div>`/`<span>`/`<p>` it is ignored. Put it on the `<button>`/`<a>`, not a wrapper.
- If a visible label *also* exists, keep the `aria-label` starting with that visible text —
  voice-control users speak what they see ("click reply"), and a divergent `aria-label` breaks
  that match.

**`title`** — renders the native browser tooltip on hover, and only contributes to the accessible
name as a **last-resort fallback**. It is an unreliable name source: it doesn't show on keyboard
focus, doesn't appear on touch devices, has poor discoverability, and some screen readers skip it.
So use `title` for a *supplementary* hint (a hover tooltip on top of a name the control already
has), not as the primary accessible name, and never to hide essential information.

In Discourse, prefer `<DButton>`, which wires both attributes for you:

```hbs
{{! icon-only — @title gives a hover tooltip AND the accessible-name fallback }}
<DButton @icon="trash-can" @title="post.controls.delete" @action={{this.delete}} />

{{! when the tooltip and the screen-reader name should differ, set both }}
<DButton @icon="bookmark" @title="bookmarks.tooltip" @ariaLabel="bookmarks.label" />
```

- `@title` / `@ariaLabel` take **i18n keys** (translated for you); `@translatedTitle` /
  `@translatedAriaLabel` take **already-translated** strings.
- A `<DButton>` with a visible `@label` doesn't need either for naming — add `@title` only for a
  supplementary tooltip.

On raw markup, label the interactive element directly with a translated string:

```hbs
<button type="button" aria-label={{i18n "post.controls.delete"}}>
  {{dIcon "trash-can"}}
</button>
```

(`dIcon` already renders the glyph `aria-hidden`, so the name belongs on the control.) For an
icon-only control you can equally use the visible-to-AT `.sr-only` span shown above — pick one
naming mechanism, not both.

## Announcing dynamic content — live regions

When content appears or a value changes without a full page navigation (async search results, a
toast, an inline validation message, a "saved" confirmation), a screen reader won't notice
unless the change happens inside an ARIA live region it is *already* observing. Discourse handles
this with a dedicated service plus a persistent set of regions.

**Announce through the `a11y` service** — never hand-roll an `aria-live` element:

```js
import { service } from "@ember/service";
// …in the component/service:
@service a11y;
// …
this.a11y.announce(i18n("search.results_count", { count }), "polite");
this.a11y.announce(i18n("errors.something_failed"), "assertive", 3000);
```

`announce(message, type = "polite", clearDelay = 2000)`:

- `type` — `"polite"` waits for the screen reader to finish what it's saying (use for most
  updates); `"assertive"` interrupts (reserve for errors / urgent state).
- `message` must be a string; the region auto-clears after `clearDelay` ms.

**Why it must go through the service:** a live region only announces changes to a region the
screen reader was already observing. The regions are mounted app-wide and stay in the DOM — see
[`components/a11y/live-regions.gjs`](../../../frontend/discourse/app/components/a11y/live-regions.gjs),
which renders persistent `#a11y-announcements-polite` (`role="status"`) and
`#a11y-announcements-assertive` (`role="alert"`) containers, and the service just updates their
text. If you instead add an `aria-live` element to the DOM at the same moment you fill it with
content, it typically **won't** announce — the region has to exist *before* the change and
persist. So never create per-message live regions; route everything through the service.

## Color, contrast & forced colors

The inline rule (in `SKILL.md`): don't signal meaning by color alone, and use the palette's
contrast-tuned pairings. The detail:

- Aim for **WCAG AA** contrast — 4.5:1 for normal text, 3:1 for large text and meaningful
  UI/graphical boundaries. The palette's intended foreground/background pairings already clear
  this; you get into trouble by improvising (e.g. `--primary-low` or `--primary-medium` text on
  a `--secondary` surface).
- **Don't convey state by color alone** — colorblind users and forced-colors mode won't perceive
  it. Pair color with an icon, text label, underline, or shape.
- **Forced colors / Windows High Contrast (WHCM).** Under `@media (forced-colors: active)` the OS
  replaces your colors with a limited system palette, so don't depend on a background or border
  color to carry meaning, and don't `outline: none` (the system outline may be the only focus
  cue). Most components inherit sensible behavior — only reach for `forced-color-adjust` or a
  `@media (forced-colors: active)` override for genuine breakage. See
  [`common/whcm.scss`](../../../app/assets/stylesheets/common/whcm.scss) and the forced-colors
  blocks in `common/components/buttons.scss` for precedent.
