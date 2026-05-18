# Code Review — `nested/timeline` branch

Branch: `nested/timeline` (3 commits ahead of `main`)
Scope: shared `<TimelineScrubber>` primitive, nested-view timeline, flat-view scroller refactor, backend `root_summary`.

---

## 🔴 Direct violations of your asks

### 1. CLAUDE.md "default to no comments" — flagrantly violated throughout

Project rule (from CLAUDE.md): *"Default to writing no comments... never write multi-paragraph docstrings or multi-line comment blocks — one short line max."*

This branch ships a lot of multi-paragraph block comments. Worst offenders:

- `frontend/discourse/app/components/timeline-scrubber.gjs:7-33` — a 27-line JSDoc-style block listing every arg, slot, and yielded value. CLAUDE.md says: *"Do not add JSDoc to any new code you write."* Delete it entirely; the names already tell the reader what they do.
- `timeline-scrubber.gjs:35-40` (SCROLLER_HEIGHT), `:42-46` (LATCH_TIMEOUT_MS), `:67-75` (latchedProgress preamble), `:88-101` (watchProgress essay), `:154-159` (railStyle). Each is 5–14 lines.
- `frontend/discourse/app/services/nested-root-elements.js:3-11` — 9-line opening, plus more multi-line interior comments at `:52-55`, `:69-71`.
- `frontend/discourse/app/controllers/nested.js:34-38, 113-117, 145-149, 175-179, 207-213` — repeats the same "backend piggybacks suggested/related" paragraph in two places.
- `frontend/discourse/app/components/nested.gjs:67-71, 80-83, 143-150` — template-side multi-line `{{! ... }}` essays.
- `frontend/discourse/app/templates/nested.gjs:16-21, 105-109` — same.
- `app/assets/stylesheets/common/topic-timeline.scss:155-158` and `common/nested-view.scss:3-9` — multi-line SCSS commentary.

**Action:** strip all of these. Keep at most one short line where the *why* is genuinely non-obvious (e.g., the microtask defer in `watchProgress`, the pinned-offset math). Everything else either explains *what* (which the code says) or is a design note that belongs in the PR description.

### 2. "legacy" framing — there's no legacy here

The old scroller is **deleted**, not coexisting. Three places still use "legacy" framing:

- `components/topic-timeline/container.gjs:30-32`:
  ```js
  // Re-exported for plugin compat — plugins historically imported this
  // from container.gjs. The canonical source is now timeline-scrubber.gjs.
  export { SCROLLER_HEIGHT };
  ```
  No plugin in this repo imports `SCROLLER_HEIGHT` from `container.gjs` (the only `setDesktopScrollAreaHeight` import lives in `lib/plugin-api.gjs`). Drop the re-export and inline-import from `timeline-scrubber.gjs` where needed. If a third-party plugin really needs it, they can update their import — it's not part of the documented plugin API.

- `container.gjs:589-591`:
  ```hbs
  {{! Restore parity with the legacy scroller component: the
      in-pill BackButton hid itself during a drag so it didn't
      visually compete with the moving handle. }}
  ```
  Either delete (it's the only behavior now — there's no "legacy" sibling) or shrink to a one-liner: `{{! Hide during drag so it doesn't fight the handle. }}`

- `topic-timeline.scss:154-157`:
  ```scss
  // Restore legacy fullscreen layout where the grip sat on the
  // right side of the pill ...
  ```
  Same — there's no legacy. Drop or shrink.

---

## 🟠 Risks introduced into the flat (non-nested) timeline

The flat scroller wasn't just refactored — it was rewritten via the shared primitive. Behavior changes that landed:

1. **`updatePercentage` removed from the date-link clicks.** Old: clicking the start-date / end-date links called `updatePercentage(e)`, which derived a click-Y and scrubbed. New: they call `@jumpTop` / `@jumpBottom` directly. Net effect is the same in practice (clicking start label → top, end label → bottom), so this is fine — but it's a real behavior change, not a refactor, and worth a note.

2. **Latch mechanism applied to flat view where it isn't needed.** `handleCommit` sets `this.percentage = progress` *synchronously* before `commit()`, so `@progress` updates the same render pass. The 2-second latch + tolerance + microtask-defer in the primitive runs anyway. Harmless but adds complexity for a problem only nested view has. Consider moving the latch out of the primitive into the *nested* timeline (a `committedProgress` tracked on `NestedTopicTimeline`, cleared when `activeGlobalIndex` catches up). That keeps the shared primitive dumb and the flat view simpler.

3. **Latent bug accidentally fixed:** old code passed `@onGoBack={{this.onGoBack}}` to `<Scroller>` but `onGoBack` was never defined on the class — so the in-pill back button was a no-op. New code uses `this.goBack` (correctly). Worth a one-line note in the PR; it's a real behavior change that users might notice.

4. **Click-on-rail now commits via pointerdown+pointerup.** The old `.timeline-padding` had an explicit click handler. The new primitive treats a click as a 0-distance drag. Should work identically, but is implementation-changed. The acceptance test was updated to reflect this.

5. **Keyboard shortcuts on the rail (Arrow/Page/Home/End) are new.** Not previously available on the flat timeline. Probably desirable, but a feature add bundled into a refactor — flag in the PR description so reviewers don't miss it.

6. **Scroller pill now has `transition: top 0.05s linear` by default** (`timeline-scrubber.scss:54`). The old flat scroller had no top transition. Visible difference under fast scroll. The `&--dragging` rule disables it during drag, but during programmatic scroll the handle now eases instead of snapping. Decide if you want this for the flat view; if not, gate it with a modifier class.

---

## 🟠 Bug: deep links into nested topics lose the timeline

`root_summary` is only attached inside `enrich_with_topic_metadata`, which is gated `only_if(:initial_page) { ... }` (page == 0). The route stores `rootSummary: data.root_summary || null`, and the template renders `{{#if @controller.rootSummary}}<NestedTopicTimeline ... />{{/if}}`.

If a user enters via a deep link that loads page > 0 (`routes/nested.js:251` accepts `data.page`), there's no `rootSummary` and **no timeline ever appears** for that session. `loadPreviousRoots` and `jumpToRootPage` don't fetch the summary either.

Two options: (a) include `root_summary` on every response, not just page 0; (b) fetch it lazily on first non-zero entry. (a) is one line and the data is cheap (two counts).

---

## 🟡 Code quality

- `services/nested-root-elements.js:78-82`: `existing_` is a weird local name (renamed to avoid shadowing the outer `existing`). Rename the outer one to `existingEl` or refactor:
  ```js
  const resolvers = this.#pendingResolvers.get(postNumber) ?? [];
  resolvers.push(resolve);
  this.#pendingResolvers.set(postNumber, resolvers);
  ```

- `controllers/nested.js:182-187`: `loadPreviousRoots` calls `elementsInOrder()` twice (once via `firstElement()`, once via `.find(entry => entry.el === anchorEl)`). Each call iterates and `getBoundingClientRect`s every registered element. Once is enough — capture the ordered list and pull index 0.

- `components/nested/topic-timeline.gjs:23-44`: the resize listener fires `#updateActive` through a rAF — fine. But the `syncOnLoadedWindow` modifier *also* requests a rAF every time `@firstLoadedPage` changes, and the `#scrollHandler` rAF can race with it. In practice they'll coalesce because both call `#updateActive`, but two simultaneous `requestAnimationFrame` callbacks reading layout is wasteful. Reuse `#rafScheduled` for the sync path too.

- `nested.gjs:140-148`: the comment block above `<DLoadMore>` explains *why* no negative rootMargin — that one is actually load-bearing. Keep that one (shortened), drop the others.

- `nested/topic-timeline.gjs:152-156`: `#commitScrub` has a fallback `window.scrollTo` branch for "no pageSize, no jumpToRootPage". In the only render site (`templates/nested.gjs`), `jumpToRootPage` is always passed and `pageSize` always present (rootSummary gate). Dead path — delete.

- `timeline-scrubber.gjs:48`: class has `@tracked dragging = false; @tracked dragProgress = 0; @tracked latchedProgress = null;` plus three private fields plus two modifier definitions plus a timeout — this primitive is doing a lot. Worth separating the latch concern out (see Risk #2 above).

---

## 🟢 Things done well

- Moving root-element tracking out of `document.querySelectorAll` into a service is a real improvement — eliminates the DOM-class coupling between the controller and timeline.
- The `waitForElement` Promise API removes the afterRender + rAF guess in the jump path; clean.
- Spec coverage for `root_summary` shape and the `has_more_roots` exact-page-boundary fix (`limit(page_size + 1)`) is solid.
- Hiding the in-page header/OP/map/controls when `firstLoadedPage > 0` and relying on the docked site header is the right call.
- `enterTopic` / `clearTopic` mirroring flat view in `routes/nested.js` is the correct integration point.

---

## Suggested cleanup order

1. Strip all multi-line block comments (highest visibility, mechanical).
2. Delete the `SCROLLER_HEIGHT` re-export and the two "legacy" comments.
3. Fix the deep-link summary gap (one-line backend change).
4. Move the latch out of the shared primitive into `NestedTopicTimeline`.
5. The smaller code-quality items.
