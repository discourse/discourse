// @ts-check

import { cancel, schedule } from "@ember/runloop";
import discourseLater from "discourse/lib/later";
import { prefersReducedMotion } from "discourse/lib/utilities";
import { entryKey, findAncestryPath } from "./mutate-layout";

// Duration of the just-selected flash; mirror the CSS animation length in
// `wireframe-chrome.scss` (`.wireframe-block-chrome.--just-selected`).
const FLASH_DURATION_MS = 1100;

/**
 * Brings a selected (or just-inserted) block to the user's attention: scrolls
 * its element into view and/or plays a one-shot flash. Both treatments tolerate
 * the element not existing yet — a structural insert re-resolves the layout over
 * a LATER revalidation, so a freshly inserted block's element isn't in the DOM
 * when it's selected. In that case the request is DEFERRED: the block's editor
 * chrome calls `notifyChromeInserted` from its `didInsert` the moment it mounts,
 * and the treatment runs then. No polling.
 *
 * A dependency-free leaf: the kernel constructs it with down-injected layout
 * readers, so it holds opaque capabilities and never reaches back into any
 * service. It owns transient presentation state (pending keys + the flash
 * timer) and has side effects (DOM + timers), so the kernel keeps it private
 * and drives it rather than exposing the instance.
 */
export default class BlockReveal {
  #findEntryAndOutletSync;
  #readResolvedLayout;

  /** @type {string|null} A selected block awaiting its element to mount. */
  #pendingRevealKey = null;

  /** @type {string|null} A block awaiting its element to mount, to flash it. */
  #pendingFlashKey = null;

  // Tracks the in-flight just-selected flash so a new flash can cancel the
  // previous one's pending class removal (see `flash`).
  #flashTimer = null;
  #flashedEl = null;

  /**
   * @param {{
   *   findEntryAndOutletSync: (key: string) => {entry: Object, outletName: string}|null,
   *   readResolvedLayout: (outletName: string) => Array<Object>|null,
   * }} deps
   */
  constructor({ findEntryAndOutletSync, readResolvedLayout }) {
    this.#findEntryAndOutletSync = findEntryAndOutletSync;
    this.#readResolvedLayout = readResolvedLayout;
  }

  /**
   * Brings the selected block into view. When its element is already rendered it
   * reveals it right away. When it isn't — a structural insert re-resolves the
   * layout over a LATER revalidation, so a just-inserted block's element doesn't
   * exist yet — the reveal is DEFERRED until the block's chrome calls
   * `notifyChromeInserted` on mount. No polling.
   *
   * @param {string|null} blockKey - The composite key of the selected block.
   */
  revealSelection(blockKey) {
    // A new selection supersedes any reveal still waiting on a mount.
    this.#pendingRevealKey = null;
    if (!blockKey) {
      return;
    }
    // If the block sits inside an inactive tab whose button is already rendered
    // (e.g. selecting it from the outline, or after a reorder), switch to that
    // tab so its panel can render. The tabs block tracks its active panel by
    // key, so activating the button sticks to the right panel even before the
    // reorder's re-render settles. A freshly INSERTED tab's button isn't mounted
    // this runloop, so this no-ops for inserts — the tabs block reveals a
    // just-added panel itself.
    this.#revealContainingTabs(blockKey);
    const el = document.querySelector(
      `[data-wf-block-key="${CSS.escape(blockKey)}"]`
    );
    if (el) {
      this.#revealElement(el);
      return;
    }
    // Not rendered yet — wait for the element to announce itself on mount.
    this.#pendingRevealKey = blockKey;
  }

  /**
   * Briefly flashes the rendered element for the given block key to draw the
   * eye to it — used when selection originates somewhere other than a direct
   * click on the block (outline selection, insert auto-select), where the
   * block may have just scrolled into view.
   *
   * Flashes right away when the element is already in the DOM. When it isn't —
   * a just-inserted block renders on a later autorun — the flash is DEFERRED:
   * the block's editor chrome calls `notifyChromeInserted` on mount, which runs
   * the flash then (the same element-announces-itself path the reveal uses).
   *
   * @param {string|null} blockKey - The composite key of the block to flash.
   */
  flash(blockKey) {
    // A new flash request supersedes any flash still waiting on a mount.
    this.#pendingFlashKey = null;
    if (!blockKey) {
      return;
    }
    const el = document.querySelector(
      `[data-wf-block-key="${CSS.escape(blockKey)}"]`
    );
    if (el) {
      this.#flashElement(el);
      return;
    }
    // Not rendered yet — wait for the element to announce itself on mount.
    this.#pendingFlashKey = blockKey;
  }

  /**
   * Called by a block's editor chrome from its `didInsert` once its element
   * exists. Runs any "just appeared" treatment we deferred because the element
   * wasn't in the DOM when the block was selected — a reveal-into-view and/or a
   * flash — so a freshly inserted (and auto-selected) block gets both exactly
   * when it renders, with no timers or polling.
   *
   * @param {string} blockKey - The mounting block's composite key.
   * @param {HTMLElement} element - The block's chrome element.
   */
  notifyChromeInserted(blockKey, element) {
    if (!blockKey) {
      return;
    }
    if (blockKey === this.#pendingRevealKey) {
      this.#pendingRevealKey = null;
      this.#revealElement(element);
    }
    if (blockKey === this.#pendingFlashKey) {
      this.#pendingFlashKey = null;
      this.#flashElement(element);
    }
  }

  /**
   * Drops all transient state: cancels an in-flight flash, strips the flash
   * class from the last flashed element, and clears the pending reveal/flash
   * keys. Idempotent. The kernel calls it both when the editing session closes
   * and at service teardown, so a flash awaiting a mount can't replay against a
   * later session.
   */
  reset() {
    if (this.#flashTimer) {
      cancel(this.#flashTimer);
      this.#flashTimer = null;
    }
    this.#flashedEl?.classList.remove("--just-selected");
    this.#flashedEl = null;
    this.#pendingRevealKey = null;
    this.#pendingFlashKey = null;
  }

  /**
   * Switches every already-rendered tab on the path to `blockKey` to the panel
   * that contains it, so selecting a block inside an inactive tab (e.g. from the
   * outline) reveals it instead of leaving it unrendered. Reveal after an INSERT
   * is the tabs block's own job (it re-renders with the new child and activates
   * it) — its button isn't mounted when this runs, so this no-ops there.
   *
   * Drives the dumb tabs block through its own data attribute: each panel's tab
   * button carries `data-wf-tab-panel-key`, and a synthesized click switches the
   * panel without changing selection (the chrome ignores `detail === 0` clicks).
   * Walks outermost to innermost; a deeply nested inner tab whose button hasn't
   * mounted yet is a best-effort case (the common single level always resolves).
   *
   * @param {string} blockKey - The composite key of the block being revealed.
   */
  #revealContainingTabs(blockKey) {
    const located = this.#findEntryAndOutletSync(blockKey);
    if (!located) {
      return;
    }
    const layout = this.#readResolvedLayout(located.outletName);
    if (!layout) {
      return;
    }
    const path = findAncestryPath(layout, blockKey);
    if (!path) {
      return;
    }
    for (const entry of path) {
      const key = entryKey(entry);
      if (!key) {
        continue;
      }
      const button = document.querySelector(
        `[data-wf-tab-panel-key="${CSS.escape(key)}"]`
      );
      if (button && button.getAttribute("aria-selected") !== "true") {
        button.click();
      }
    }
  }

  /**
   * Scrolls `el` into view. Centers it when it fits the viewport; aligns to the
   * top when it's taller. Skips scrolling when it's already adequately visible,
   * so selecting an on-screen block doesn't jolt the page. Respects the
   * reduced-motion preference. Runs in `afterRender` so sibling layout (e.g. a
   * carousel track's widths) is settled before measuring.
   *
   * @param {HTMLElement} el - The element to reveal.
   */
  #revealElement(el) {
    schedule("afterRender", () => {
      if (!el.isConnected) {
        return;
      }

      const rect = el.getBoundingClientRect();
      const viewportHeight = window.innerHeight;
      const behavior = prefersReducedMotion() ? "auto" : "smooth";
      // A block taller than the viewport can never be fully centered, so we
      // only require its top to be on screen and align to the top on scroll.
      const tallerThanViewport = rect.height > viewportHeight;

      const vertVisible = tallerThanViewport
        ? rect.top >= 0 && rect.top <= viewportHeight
        : rect.top >= 0 && rect.bottom <= viewportHeight;

      // Horizontal visibility within the nearest inline-scrollable ancestor
      // (e.g. a carousel's slide track): a block can be vertically on screen
      // yet scrolled out of view along the track. With no such ancestor there
      // is nothing to reveal horizontally.
      const scroller = this.#nearestInlineScroller(el);
      let horizVisible = true;
      if (scroller) {
        const scrollerRect = scroller.getBoundingClientRect();
        horizVisible =
          rect.left >= scrollerRect.left && rect.right <= scrollerRect.right;
      }

      if (vertVisible && horizVisible) {
        return;
      }

      el.scrollIntoView({
        // Keep the vertical position when it's already visible, so revealing a
        // horizontally-clipped slide doesn't also jolt the page vertically.
        block: vertVisible
          ? "nearest"
          : tallerThanViewport
            ? "start"
            : "center",
        // Align to the inline start, not "nearest": an inline scroller is
        // typically a snap track (e.g. a carousel with `scroll-snap-type:
        // x mandatory`), where a partial "nearest" scroll lands off a snap
        // point and the browser snaps back. "start" matches the snap-aligned
        // position the track scrolls to itself.
        inline: "start",
        behavior,
      });
    });
  }

  /**
   * Walks up from an element to the nearest ancestor that scrolls on the inline
   * (horizontal) axis and is actually overflowing — e.g. a carousel's slide
   * track. Returns `null` when there is none.
   *
   * @param {HTMLElement} el - The element to search up from.
   * @returns {HTMLElement|null}
   */
  #nearestInlineScroller(el) {
    let node = el.parentElement;
    while (node && node !== document.body) {
      const overflowX = getComputedStyle(node).overflowX;
      if (
        (overflowX === "auto" || overflowX === "scroll") &&
        node.scrollWidth > node.clientWidth
      ) {
        return node;
      }
      node = node.parentElement;
    }
    return null;
  }

  /**
   * Replays the one-shot "just selected" flash on `el`. Toggling the class with
   * a forced reflow restarts the animation even when the same block is
   * re-selected; a cancelable timer removes the class so the next flash can
   * replay it.
   *
   * Scheduled in `afterRender` because a flash usually rides along with a
   * selection change (outline selection, insert auto-select), and that
   * selection toggles the chrome's class binding. Mutating the class after the
   * render settles keeps Ember from rewriting the element's class attribute out
   * from under us and wiping the flash class we just added.
   *
   * @param {HTMLElement} el - The element to flash.
   */
  #flashElement(el) {
    schedule("afterRender", () => {
      if (!el.isConnected) {
        return;
      }

      // Cancel any in-flight flash (possibly on a different block) so its
      // pending removal doesn't strip the class we're about to add.
      if (this.#flashTimer) {
        cancel(this.#flashTimer);
        this.#flashedEl?.classList.remove("--just-selected");
      }

      el.classList.remove("--just-selected");
      void el.offsetWidth;
      el.classList.add("--just-selected");
      this.#flashedEl = el;

      this.#flashTimer = discourseLater(() => {
        el.classList.remove("--just-selected");
        this.#flashTimer = null;
        this.#flashedEl = null;
      }, FLASH_DURATION_MS);
    });
  }
}
