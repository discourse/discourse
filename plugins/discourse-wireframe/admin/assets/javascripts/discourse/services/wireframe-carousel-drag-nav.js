// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import Service from "@ember/service";
import discourseLater from "discourse/lib/later";

/** Dwell (ms) the cursor must rest on a nav dot before the carousel pages. */
const PAGE_DELAY_MS = 300;

/**
 * Drag-time navigation of carousels in the editor. While a block drag is in
 * flight, hovering a carousel's nav dot pages that carousel to the dot's slide
 * (after a short dwell), so an off-screen slide can be reached as a drop target.
 *
 * Driven by the editor shell's drag monitor: the shell wires the monitor's
 * `onDragStart` / `onDrag` / `onDrop` to these handlers, so the behaviour lives
 * here (reusable, testable) rather than in the chrome component.
 *
 * The drop overlay never paints over the nav controls (they carry
 * `data-wf-drop-exclude`, which the container drop target honours), so paging
 * needs no overlay coordination. Reads only passive carousel markers
 * (`data-wf-carousel`, `data-wf-drop-container`, `data-wf-carousel-nav`,
 * `data-wf-carousel-slide-index`); the carousel block stays a dumb renderer.
 */
export default class WireframeCarouselDragNavService extends Service {
  /**
   * The nav dot whose page is currently scheduled (or was last hovered), so a
   * steady hover doesn't reschedule the dwell timer every drag frame. `null`
   * when the cursor is over no dot.
   *
   * @type {HTMLElement|null}
   */
  #lastHoveredDot = null;

  /** Handle for the hover-intent dwell timer (`discourseLater`). */
  #pageTimer = null;

  constructor() {
    super(...arguments);
    registerDestructor(this, () => cancel(this.#pageTimer));
  }

  /** Drag started: clear any carry-over so the first dwell pages cleanly. */
  @action
  handleDragStart() {
    this.#reset();
  }

  /**
   * Drag moved (per frame): page the carousel whose nav dot the cursor dwells
   * on.
   *
   * @param {{ location: Object }} event - PDND monitor event.
   */
  @action
  handleDrag({ location }) {
    const input = location?.current?.input;
    if (!input) {
      return;
    }
    // Hover-intent: page only after the cursor dwells on a dot, so sweeping
    // across dots doesn't fire a burst of scrolls.
    const dot = this.#carouselDotAt(input.clientX, input.clientY);
    if (dot === this.#lastHoveredDot) {
      return;
    }
    this.#lastHoveredDot = dot;
    cancel(this.#pageTimer);
    this.#pageTimer = null;
    if (dot) {
      this.#pageTimer = discourseLater(
        () => this.#pageCarouselToDot(dot),
        PAGE_DELAY_MS
      );
    }
  }

  /** Drag ended: cancel any pending dwell. */
  @action
  handleDrop() {
    this.#reset();
  }

  #reset() {
    cancel(this.#pageTimer);
    this.#pageTimer = null;
    this.#lastHoveredDot = null;
  }

  /**
   * Returns the carousel nav dot under the given viewport coordinates, or
   * `null`. Uses a rect hit-test (not `elementFromPoint`) so the drag preview
   * floating under the cursor doesn't shadow the dot. Only dots carry both the
   * nav marker and a slide index, so the prev/next buttons are skipped.
   *
   * @param {number} x
   * @param {number} y
   * @returns {HTMLElement|null}
   */
  #carouselDotAt(x, y) {
    const dots = document.querySelectorAll(
      "[data-wf-carousel-nav][data-wf-carousel-slide-index]"
    );
    for (const dot of dots) {
      const r = dot.getBoundingClientRect();
      if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) {
        return dot;
      }
    }
    return null;
  }

  /**
   * Scrolls the slide the given dot points at into view, so a drag can reach a
   * slide that's currently off-screen. Walks from the dot up to its carousel
   * root, then down to the marked viewport, whose Nth child is the Nth slide.
   *
   * @param {HTMLElement} dot
   */
  #pageCarouselToDot(dot) {
    this.#pageTimer = null;
    const index = parseInt(dot.dataset.wfCarouselSlideIndex, 10);
    if (Number.isNaN(index)) {
      return;
    }
    const viewport = dot
      .closest("[data-wf-carousel]")
      ?.querySelector("[data-wf-drop-container]");
    const slide = viewport?.children?.[index];
    slide?.scrollIntoView({
      behavior: prefersReducedMotion() ? "auto" : "smooth",
      block: "nearest",
      inline: "start",
    });
  }
}

/**
 * Whether the OS "reduce motion" preference is set, so a slide reveal can fall
 * back to an instant jump instead of a smooth scroll.
 *
 * @returns {boolean}
 */
function prefersReducedMotion() {
  return !!window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
}
