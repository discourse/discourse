import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import type WireframeRailService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-rail";

interface RailResizeHandleSignature {
  /** Rail-side selection for the resize handle. */
  Args: {
    /** Rail whose inner edge this handle resizes. */
    side: "left" | "right";
  };
}

/**
 * The separator at a rail's inner seam that resizes the rail. Rendered as a
 * DIRECT child of the shell grid (so it inherits the shell's
 * `pointer-events: auto` re-enable and can't be clipped by the panel's
 * `overflow: hidden`), positioned over the seam by its stylesheet.
 *
 * The gesture, the keyboard path and the splitter semantics all come from
 * `DResizeSeparator`; this component only names which rail is resized and
 * hands sizes to the `wireframe-rail` service, previewing during the gesture
 * and persisting when it ends.
 *
 * Args:
 *  - `@side` — `"left"` (resizes the left panel; its inner edge faces the canvas)
 *    or `"right"` (resizes the right inspector rail).
 */
export default class RailResizeHandle extends Component<RailResizeHandleSignature> {
  /** Reads, previews, and persists rail widths. */
  @service declare wireframeRail: WireframeRailService;

  /**
   * Whether a resize is in progress, for the seam's own highlight; the
   * separator marks the body, not itself. `@tracked` cannot sit on a `#`
   * field, hence the prefix.
   */
  @tracked _resizing = false;

  /** Whether this handle controls the left rail. */
  get #isLeft(): boolean {
    return this.args.side === "left";
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
   * Which edge of the rail the handle sits on, in the separator's terms: the
   * left panel grows as its handle moves toward the inline end, the right
   * rail as its handle moves toward the inline start.
   */
  get side(): "start" | "end" {
    return this.#isLeft ? "start" : "end";
  }

  @action
  onResizeStart(): void {
    this._resizing = true;
  }

  /**
   * Applies a live width preview.
   *
   * @param width - The width the gesture is at.
   */
  @action
  onResize(width: number): void {
    this.#setWidth(width, { commit: false });
  }

  /**
   * Persists the width the gesture settled on.
   *
   * @param width - The final width.
   */
  @action
  onResizeEnd(width: number): void {
    this._resizing = false;
    this.#setWidth(width, { commit: true });
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
    <DResizeSeparator
      class={{dConcatClass
        "wireframe-rail-resizer"
        (concat "wireframe-rail-resizer--" @side)
        (if this._resizing "--resizing")
      }}
      @axis="horizontal"
      @side={{this.side}}
      @label={{this.label}}
      @value={{this.width}}
      @min={{this.min}}
      @max={{this.max}}
      @onResizeStart={{this.onResizeStart}}
      @onResize={{this.onResize}}
      @onResizeEnd={{this.onResizeEnd}}
    />
  </template>
}
