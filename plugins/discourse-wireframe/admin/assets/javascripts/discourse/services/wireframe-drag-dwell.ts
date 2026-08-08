import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { cancel, type Timer } from "@ember/runloop";
import Service from "@ember/service";
import discourseLater from "discourse/lib/later";

/** Dwell (ms) the cursor must rest on a control before its target is revealed. */
const REVEAL_DELAY_MS = 300;

/**
 * A reveal target for the nav control under the cursor: `element` is the control
 * the dwell de-dupe keys on, `reveal` performs the block-appropriate navigation.
 */
type RevealTarget = {
  /** Navigation control under the drag pointer. */
  element: HTMLElement;
  /** Reveals the block destination represented by the control. */
  reveal: () => void;
};

/**
 * Drag-time navigation of paged container blocks in the editor. While a block
 * drag is in flight, hovering a container's navigation control reveals the
 * target it points at (after a short dwell), so a slide / panel that isn't
 * currently presented can still be reached as a drop target. Two block families
 * use it today:
 *
 *  - **Carousel** — hovering a nav dot scrolls that slide into view. Every slide
 *    is already in the DOM, so the reveal is a plain `scrollIntoView`.
 *  - **Tabs** — hovering a tab pages to its panel. Only the active panel is
 *    rendered, so the reveal clicks the tab button: the block's own click
 *    handler switches the active panel (and a synthesized click — `detail === 0`
 *    — never reaches the chrome's block-selection routing, so selection is
 *    untouched, matching the carousel).
 *
 * Driven by the editor shell's drag monitor: the shell wires the monitor's
 * `onDragStart` / `onDrag` / `onDrop` to these handlers, so the behaviour lives
 * here (reusable, testable) rather than in the chrome component.
 *
 * Reads only passive markers the blocks expose in an editing context
 * (`data-wf-carousel`, `data-wf-drop-container`, `data-wf-carousel-nav`,
 * `data-wf-carousel-slide-index`, `data-wf-tab-panel-key`); the blocks stay dumb
 * renderers. The drop overlay never paints over a block's nav controls (the
 * carousel marks its controls `data-wf-drop-exclude` and the tab strip is not a
 * marked drop container), so revealing a target needs no overlay coordination.
 */
export default class WireframeDragDwellService extends Service {
  /**
   * The control whose reveal is currently scheduled (or was last hovered), so a
   * steady hover doesn't reschedule the dwell timer every drag frame. `null`
   * when the cursor is over no control.
   */
  #lastHoveredControl: HTMLElement | null = null;

  /** Handle for the hover-intent dwell timer (`discourseLater`). */
  #revealTimer: Timer | null = null;

  /**
   * Creates the service and registers timer cleanup with Ember destruction.
   *
   * @param owner - Ember owner used to initialize the service.
   */
  constructor(owner: Owner) {
    super(owner);
    registerDestructor(this, () => cancel(this.#revealTimer ?? undefined));
  }

  /** Drag started: clear any carry-over so the first dwell reveals cleanly. */
  @action
  handleDragStart(): void {
    this.#reset();
  }

  /**
   * Drag moved (per frame): reveal the target of the nav control the cursor
   * dwells on.
   *
   * @param event - Drag-monitor event containing the current pointer location.
   */
  @action
  handleDrag({
    location,
  }: {
    /** Current drag-monitor location, when pointer data is available. */
    location?: {
      /** Most recent pointer snapshot. */
      current?: {
        /** Pointer coordinates supplied by the drag monitor. */
        input?: {
          /** Horizontal viewport coordinate of the drag pointer. */
          clientX: number;
          /** Vertical viewport coordinate of the drag pointer. */
          clientY: number;
        };
      };
    };
  }): void {
    const input = location?.current?.input;
    if (!input) {
      return;
    }
    // Hover-intent: reveal only after the cursor dwells on a control, so
    // sweeping across controls doesn't fire a burst of reveals.
    const target = this.#revealTargetAt(input.clientX, input.clientY);
    const element = target?.element ?? null;
    if (element === this.#lastHoveredControl) {
      return;
    }
    this.#lastHoveredControl = element;
    cancel(this.#revealTimer ?? undefined);
    this.#revealTimer = null;
    if (target) {
      this.#revealTimer = discourseLater(() => {
        this.#revealTimer = null;
        target.reveal();
      }, REVEAL_DELAY_MS);
    }
  }

  /** Drag ended: cancel any pending dwell. */
  @action
  handleDrop(): void {
    this.#reset();
  }

  /** Cancels the reveal timer and forgets the last hovered control. */
  #reset(): void {
    cancel(this.#revealTimer ?? undefined);
    this.#revealTimer = null;
    this.#lastHoveredControl = null;
  }

  /**
   * Returns the reveal target for the nav control under the given viewport
   * coordinates, or `null`. Carousel dots are matched first, then tab buttons;
   * the two selectors are disjoint, so order only affects the (benign) nested
   * case.
   *
   * @param x - Horizontal viewport coordinate of the drag pointer.
   * @param y - Vertical viewport coordinate of the drag pointer.
   */
  #revealTargetAt(x: number, y: number): RevealTarget | null {
    // Only carousel dots carry both the nav marker and a slide index, so the
    // prev/next buttons are skipped.
    const dot = this.#elementAt(
      x,
      y,
      "[data-wf-carousel-nav][data-wf-carousel-slide-index]"
    );
    if (dot) {
      return { element: dot, reveal: () => this.#scrollCarouselToDot(dot) };
    }
    // A tab is revealed only when the cursor dwells on its CENTER third: the
    // outer thirds of a tab button are the strip's insert boundaries (a drop
    // there adds a new tab), so the two behaviours never act on the same pixels.
    const tab = this.#elementAt(x, y, "[data-wf-tab-panel-key]");
    if (tab && this.#isInCenterThird(tab, x)) {
      // The tab button's own click handler switches the active panel; the
      // synthesized click (`detail === 0`) never reaches the chrome's
      // block-selection routing, so revealing a panel doesn't change selection.
      return { element: tab, reveal: () => tab.click() };
    }
    return null;
  }

  /**
   * Whether `x` falls in the horizontal center third of `el`'s bounding rect.
   *
   * @param el - Navigation control being hit-tested.
   * @param x - Horizontal viewport coordinate of the drag pointer.
   */
  #isInCenterThird(el: HTMLElement, x: number): boolean {
    const r = el.getBoundingClientRect();
    const third = r.width / 3;
    return x >= r.left + third && x <= r.right - third;
  }

  /**
   * Returns the first element matching `selector` whose bounding rect contains
   * the given viewport coordinates, or `null`. Uses a rect hit-test (not
   * `elementFromPoint`) so the drag preview floating under the cursor doesn't
   * shadow the control.
   *
   * @param x - Horizontal viewport coordinate of the drag pointer.
   * @param y - Vertical viewport coordinate of the drag pointer.
   * @param selector - Selector for candidate navigation controls.
   */
  #elementAt(x: number, y: number, selector: string): HTMLElement | null {
    for (const el of document.querySelectorAll<HTMLElement>(selector)) {
      const r = el.getBoundingClientRect();
      if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) {
        return el;
      }
    }
    return null;
  }

  /**
   * Scrolls the slide the given dot points at into view, so a drag can reach a
   * slide that's currently off-screen. Walks from the dot up to its carousel
   * root, then down to the marked viewport, whose Nth child is the Nth slide.
   *
   * @param dot - Carousel navigation dot identifying the target slide.
   */
  #scrollCarouselToDot(dot: HTMLElement): void {
    const index = parseInt(dot.dataset.wfCarouselSlideIndex ?? "", 10);
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
 */
function prefersReducedMotion(): boolean {
  return !!window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
}
