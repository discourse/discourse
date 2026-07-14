// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import { i18n } from "discourse-i18n";

// Pixels per keyboard step (Arrow keys). Matches the granularity a keyboard user
// expects from a splitter without being tediously fine.
const STEP = 16;

/**
 * A draggable / keyboard-operable separator at a rail's inner seam that resizes
 * the rail. Rendered as a DIRECT child of the shell grid (so it inherits the
 * shell's `pointer-events: auto` re-enable and can't be clipped by the panel's
 * `overflow: hidden`), positioned over the seam by its stylesheet.
 *
 * Pointer drag is delegated to the shared `DResizeHandles` (which reports a
 * pointer delta); this component turns that delta into a new rail width on the
 * `wireframe-rail` service. Keyboard operation follows the WAI-ARIA window
 * splitter pattern: the root is a focusable `role="separator"` with live
 * `aria-valuenow`/min/max, and Arrow keys nudge the width, Home/End snap to the
 * bounds. `aria-orientation` is `vertical` because the separator itself is a
 * vertical divider between side-by-side columns (its drag axis is horizontal).
 *
 * Args:
 *  - `@side` — `"left"` (resizes the left panel; its inner edge faces the canvas)
 *    or `"right"` (resizes the right inspector rail).
 */
export default class RailResizeHandle extends Component {
  @service wireframeRail;

  /** @type {number} Width snapshot captured at drag start. */
  #startWidth = 0;

  get #isLeft() {
    return this.args.side === "left";
  }

  /** @returns {boolean} Whether the document is right-to-left. */
  get #rtl() {
    return document.documentElement.getAttribute("dir") === "rtl";
  }

  /** @returns {number} The current width of the rail this handle resizes. */
  get width() {
    return this.#isLeft
      ? this.wireframeRail.leftPanelWidth
      : this.wireframeRail.rightRailWidth;
  }

  get min() {
    return this.#isLeft
      ? this.wireframeRail.leftPanelMin
      : this.wireframeRail.rightRailMin;
  }

  get max() {
    return this.#isLeft
      ? this.wireframeRail.leftPanelMax
      : this.wireframeRail.rightRailMax;
  }

  /** @returns {string} Translated accessible name distinguishing the two seams. */
  get label() {
    return i18n(
      this.#isLeft
        ? "wireframe.chrome.resize_left_panel"
        : "wireframe.chrome.resize_right_panel"
    );
  }

  /**
   * The single edge handle `DResizeHandles` should render: the left panel's east
   * edge, the right rail's west edge.
   *
   * @returns {Array<string>}
   */
  get directions() {
    return [this.#isLeft ? "e" : "w"];
  }

  @action
  onResizeStart() {
    this.#startWidth = this.width;
  }

  @action
  onResize(_payload, dragInfo) {
    this.#setWidth(this.#startWidth + this.#growth(dragInfo.delta.x), {
      commit: false,
    });
  }

  @action
  onResizeEnd() {
    // Persist the width settled on during the live drag.
    this.#setWidth(this.width, { commit: true });
  }

  @action
  onKeyDown(event) {
    let physical;
    switch (event.key) {
      case "ArrowRight":
        physical = STEP;
        break;
      case "ArrowLeft":
        physical = -STEP;
        break;
      case "Home":
        event.preventDefault();
        this.#setWidth(this.min, { commit: true });
        return;
      case "End":
        event.preventDefault();
        this.#setWidth(this.max, { commit: true });
        return;
      default:
        return;
    }
    event.preventDefault();
    this.#setWidth(this.width + this.#growth(physical), { commit: true });
  }

  /**
   * Turns a signed pointer/keyboard movement (in physical pixels, positive =
   * rightward) into a width delta for this rail, accounting for which edge the
   * handle sits on and text direction.
   *
   * @param {number} physical
   * @returns {number}
   */
  #growth(physical) {
    // The left panel grows as its right edge moves right; the right rail grows as
    // its left edge moves left. RTL mirrors the horizontal axis.
    const sign = (this.#isLeft ? 1 : -1) * (this.#rtl ? -1 : 1);
    return physical * sign;
  }

  /**
   * @param {number} px
   * @param {{ commit?: boolean }} options
   */
  #setWidth(px, options) {
    if (this.#isLeft) {
      this.wireframeRail.setLeftPanelWidth(px, options);
    } else {
      this.wireframeRail.setRightRailWidth(px, options);
    }
  }

  <template>
    <div
      class="wireframe-rail-resizer wireframe-rail-resizer--{{@side}}"
      role="separator"
      aria-orientation="vertical"
      aria-label={{this.label}}
      aria-valuenow={{this.width}}
      aria-valuemin={{this.min}}
      aria-valuemax={{this.max}}
      tabindex="0"
      {{on "keydown" this.onKeyDown}}
    >
      <DResizeHandles
        @handleClass="wireframe-rail-resizer__grip"
        @directions={{this.directions}}
        @onResizeStart={{this.onResizeStart}}
        @onResize={{this.onResize}}
        @onResizeEnd={{this.onResizeEnd}}
        @draggingClass="--dragging"
      />
    </div>
  </template>
}
