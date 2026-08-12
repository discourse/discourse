import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import { i18n } from "discourse-i18n";
import type WireframeRailService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-rail";

// Pixels per keyboard step (Arrow keys). Matches the granularity a keyboard user
// expects from a splitter without being tediously fine.
const STEP = 16;

interface RailResizeHandleSignature {
  /** Rail-side selection for the resize handle. */
  Args: {
    /** Rail whose inner edge this handle resizes. */
    side: "left" | "right";
  };
}

type ResizeDragInfo = {
  /** Pointer displacement since drag start. */
  delta: {
    /** Horizontal displacement in pixels. */
    x: number;
  };
};

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
export default class RailResizeHandle extends Component<RailResizeHandleSignature> {
  /** Reads, previews, and persists rail widths. */
  @service declare wireframeRail: WireframeRailService;

  /** Width snapshot captured at drag start. */
  #startWidth: number = 0;

  /** Whether this handle controls the left rail. */
  get #isLeft(): boolean {
    return this.args.side === "left";
  }

  /** Whether the document is right-to-left. */
  get #rtl(): boolean {
    return document.documentElement.getAttribute("dir") === "rtl";
  }

  /** The current width of the rail this handle resizes. */
  get width(): number {
    return this.#isLeft
      ? this.wireframeRail.leftPanelWidth
      : this.wireframeRail.rightRailWidth;
  }

  /** Minimum permitted rail width. */
  get min(): number {
    return this.#isLeft
      ? this.wireframeRail.leftPanelMin
      : this.wireframeRail.rightRailMin;
  }

  /** Maximum permitted rail width. */
  get max(): number {
    return this.#isLeft
      ? this.wireframeRail.leftPanelMax
      : this.wireframeRail.rightRailMax;
  }

  /** Translated accessible name distinguishing the two seams. */
  get label(): string {
    return i18n(
      this.#isLeft
        ? "wireframe.chrome.resize_left_panel"
        : "wireframe.chrome.resize_right_panel"
    );
  }

  /**
   * The single edge handle `DResizeHandles` should render: the left panel's east
   * edge, the right rail's west edge.
   */
  get directions(): ("e" | "w")[] {
    return [this.#isLeft ? "e" : "w"];
  }

  /** Captures the current width at the beginning of a pointer resize. */
  @action
  onResizeStart(): void {
    this.#startWidth = this.width;
  }

  /**
   * Applies a live width preview from pointer displacement.
   *
   * @param _payload - Direction payload supplied by the resize component.
   * @param dragInfo - Pointer displacement for the current frame.
   */
  @action
  onResize(
    /** Direction payload supplied by the shared resize component. */
    _payload: unknown,
    /** Pointer displacement for the current resize frame. */
    dragInfo: ResizeDragInfo
  ): void {
    this.#setWidth(this.#startWidth + this.#growth(dragInfo.delta.x), {
      commit: false,
    });
  }

  /** Persists the width settled on at the end of a pointer resize. */
  @action
  onResizeEnd(): void {
    // Persist the width settled on during the live drag.
    this.#setWidth(this.width, { commit: true });
  }

  /**
   * Applies arrow, Home, and End keyboard resizing.
   *
   * @param event - Separator keyboard event.
   */
  @action
  onKeyDown(event: KeyboardEvent): void {
    let physical: number;
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
   * @param physical - Signed horizontal movement in physical pixels.
   * @returns Corresponding signed rail-width delta.
   */
  #growth(physical: number): number {
    // The left panel grows as its right edge moves right; the right rail grows as
    // its left edge moves left. RTL mirrors the horizontal axis.
    const sign = (this.#isLeft ? 1 : -1) * (this.#rtl ? -1 : 1);
    return physical * sign;
  }

  /**
   * @param px - Replacement rail width in pixels.
   * @param options - Controls whether the new width is persisted.
   */
  #setWidth(
    px: number,
    options: {
      /** Whether the replacement width should be persisted. */
      commit?: boolean;
    }
  ): void {
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
