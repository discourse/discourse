// @ts-check
import { schedule } from "@ember/runloop";
import Service from "@ember/service";

/**
 * Required slack, in pixels, between the available width and a tier's natural
 * width before we let that tier win. Absorbs sub-pixel rounding (and the small
 * error from summing several elements' `offsetWidth`s) so a badge sitting right
 * on a boundary doesn't flip back and forth.
 */
const EPSILON = 1;

/**
 * The fit tier for a badge, chosen purely from measured widths. Exported as a
 * pure function so the decision can be unit-tested without a DOM.
 *
 *   - `full`     — the whole inline bar fits, so every action stays inline.
 *   - `narrow`   — the full bar doesn't fit, but the identity handle plus the
 *                  hamburger does, so the actions fold into the hamburger.
 *   - `narrower` — even handle + hamburger doesn't fit, so the handle drops its
 *                  name (to a tooltip) and only the grip + hamburger remain.
 *
 * @param {number} avail - The block's available content width (`chrome.clientWidth`).
 * @param {number} naturalFull - The bar's natural width with all actions inline.
 * @param {number} naturalCompact - The bar's natural width with the actions folded
 *   into the hamburger (handle + hamburger).
 * @returns {"full"|"narrow"|"narrower"}
 */
export function computeTier(avail, naturalFull, naturalCompact) {
  if (avail >= naturalFull + EPSILON) {
    return "full";
  }
  if (avail >= naturalCompact + EPSILON) {
    return "narrow";
  }
  return "narrower";
}

/**
 * Coordinates the overflow-collapse ("fit") of every selected block badge
 * (`wireframe-block-toolbar`) through ONE shared `ResizeObserver`.
 *
 * A badge is rendered for every block chrome and is far wider than a thin block
 * when its action row is showing, so it would overflow. Each selected badge's
 * `toolbar-fit` modifier registers its chrome here; the shared observer watches
 * the chrome's width and writes a `data-wf-toolbar-fit` tier attribute that the
 * stylesheet keys off to fold the actions into a hamburger as space runs out.
 *
 * Only SELECTED badges register (a badge's action region only renders while
 * selected), so the observed set is the selection set — never one-per-block —
 * which keeps the cost flat at canvas scale even though a badge exists per
 * block. One observer over N targets (vs N observers) also lets us batch the
 * measure into a single read-all-then-write-all pass, avoiding layout thrash.
 *
 * This is a dependency-free coordination leaf in the spirit of
 * `wireframe-drag-overlay`: it injects nothing, never reaches back into the
 * editor kernel or any component, and writes only a data attribute on the
 * chrome elements it's handed. Its lifetime is the app instance; `willDestroy`
 * tears the observer down, and each badge unregisters as it deselects or unmounts.
 */
export default class WireframeToolbarFit extends Service {
  /** @type {ResizeObserver|null} */
  #observer = null;

  /** @type {(() => void)|null} The bound window-resize handler, when attached. */
  #onWindowResize = null;

  /**
   * Registered badges, keyed by the observed chrome element.
   *
   * @type {Map<HTMLElement, { toolbarEl: HTMLElement }>}
   */
  #registry = new Map();

  /** Whether a measure pass is already queued for the next `afterRender`. */
  #measureScheduled = false;

  willDestroy() {
    super.willDestroy();
    this.#observer?.disconnect();
    this.#observer = null;
    if (this.#onWindowResize) {
      window.removeEventListener("resize", this.#onWindowResize);
      this.#onWindowResize = null;
    }
    this.#registry.clear();
  }

  /**
   * Starts tracking a selected badge: observes its chrome's width and computes
   * its initial tier. Idempotent — re-registering the same chrome just updates
   * the toolbar element and re-measures.
   *
   * @param {HTMLElement} chromeEl - The block's chrome element (the width we track).
   * @param {HTMLElement} toolbarEl - The badge root, queried for its measured parts.
   */
  register(chromeEl, toolbarEl) {
    if (!chromeEl || !toolbarEl) {
      return;
    }
    this.#registry.set(chromeEl, { toolbarEl });
    this.#ensureObserver();
    this.#observer?.observe(chromeEl);
    this.#scheduleMeasure();
  }

  /**
   * Re-measures a badge whose content may have changed width without a resize
   * (a different action set, a relabelled handle, a locale switch). The badge's
   * modifier calls this on every update; a plain resize is handled by the
   * observer alone.
   *
   * @param {HTMLElement} chromeEl - The registered chrome element.
   */
  refresh(chromeEl) {
    if (this.#registry.has(chromeEl)) {
      this.#scheduleMeasure();
    }
  }

  /**
   * Stops tracking a badge (it deselected or unmounted) and drops its tier
   * attribute. Idempotent: a second call — e.g. the destructor backstop firing
   * after a deselect already unregistered — is a no-op, and `unobserve` on an
   * un-observed element is harmless.
   *
   * @param {HTMLElement} chromeEl - The chrome element to stop tracking.
   */
  unregister(chromeEl) {
    if (!this.#registry.delete(chromeEl)) {
      return;
    }
    this.#observer?.unobserve(chromeEl);
    chromeEl.removeAttribute("data-wf-toolbar-fit");
  }

  /**
   * Lazily builds the single shared observer plus the window-resize fallback on
   * first registration. The observer fires on per-block width changes (e.g. a
   * grid cell being resized); the window listener catches reflows that change a
   * block's width without resizing the observed box directly.
   */
  #ensureObserver() {
    if (this.#observer) {
      return;
    }
    this.#observer = new ResizeObserver(() => this.#scheduleMeasure());
    this.#onWindowResize = () => this.#scheduleMeasure();
    window.addEventListener("resize", this.#onWindowResize);
  }

  /**
   * Coalesces every measure trigger in a runloop into one `afterRender` pass, so
   * a burst (multiple resizes, a multi-select) measures once.
   */
  #scheduleMeasure() {
    if (this.#measureScheduled) {
      return;
    }
    this.#measureScheduled = true;
    schedule("afterRender", this, this.#measureAll);
  }

  /**
   * Measures every registered badge and writes its tier. Strictly read-all then
   * write-all: all width reads happen first (one layout flush for the batch),
   * then all attribute writes — so a write never forces a reflow before the next
   * badge's read. Writes are diffed so an unchanged tier touches no DOM.
   */
  #measureAll() {
    this.#measureScheduled = false;

    // Read phase — pure measurement, no writes.
    const decisions = [];
    for (const [chromeEl, { toolbarEl }] of this.#registry) {
      if (!chromeEl.isConnected || !toolbarEl.isConnected) {
        continue;
      }
      decisions.push([chromeEl, this.#tierFor(chromeEl, toolbarEl)]);
    }

    // Write phase — attribute writes only, no measurement.
    for (const [chromeEl, tier] of decisions) {
      if (chromeEl.getAttribute("data-wf-toolbar-fit") !== tier) {
        chromeEl.setAttribute("data-wf-toolbar-fit", tier);
      }
    }
  }

  /**
   * Reads a badge's natural widths and resolves its tier. The leading group
   * (handle + any always-inline format buttons) and BOTH the collapsible action
   * row and the hamburger are always in the DOM — the off-tier one sits
   * absolutely positioned at `max-content`, so every `offsetWidth` reports its
   * true intrinsic width regardless of the current tier. No styles are toggled
   * to measure.
   *
   * @param {HTMLElement} chromeEl
   * @param {HTMLElement} toolbarEl
   * @returns {"full"|"narrow"|"narrower"}
   */
  #tierFor(chromeEl, toolbarEl) {
    const widthOf = (selector) =>
      toolbarEl.querySelector(selector)?.offsetWidth ?? 0;

    // Everything that is always inline and never collapses.
    const leading =
      widthOf(".wireframe-block-toolbar__handle") +
      widthOf(".wireframe-block-toolbar__format");
    const actions = widthOf(".wireframe-block-toolbar__actions");
    const more = widthOf(".wireframe-block-toolbar__more");

    return computeTier(chromeEl.clientWidth, leading + actions, leading + more);
  }
}
