// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

const MIN_DIM = 40;

/**
 * Resolves the active axes for a compass direction. `signX` / `signY` translate
 * a raw pointer delta into a width / height delta (dragging the `w` edge LEFT
 * grows the width, so `signX` is `-1` for `w`). A `0` axis means that edge
 * doesn't move (so the dimension is held).
 *
 * @param {string} direction - One of `nw|n|ne|e|se|s|sw|w`.
 * @returns {{signX: number, signY: number}}
 */
function deltaSigns(direction) {
  let signX = 0;
  let signY = 0;
  if (direction.includes("e")) {
    signX = 1;
  }
  if (direction.includes("w")) {
    signX = -1;
  }
  if (direction.includes("s")) {
    signY = 1;
  }
  if (direction.includes("n")) {
    signY = -1;
  }
  return { signX, signY };
}

/**
 * Pure image-resize math: given the origin dimensions, the handle direction,
 * and the raw pointer delta, returns the new `{width, height}` in pixels.
 *
 * Aspect-lock is on by default; holding Shift releases it. For a corner drag
 * either axis can lead (whichever moved more in proportion); for an edge drag
 * the dragged axis leads and the other follows the ratio. Both dimensions are
 * floored at `MIN_DIM` and rounded.
 *
 * @param {Object} params
 * @param {number} params.originWidth
 * @param {number} params.originHeight
 * @param {string} params.direction
 * @param {number} params.deltaX - Raw pointer delta (current - origin), x.
 * @param {number} params.deltaY - Raw pointer delta (current - origin), y.
 * @param {boolean} params.shiftKey - When true, release the aspect lock.
 * @param {?number} params.aspect - The locked aspect ratio, or null.
 * @returns {{width: number, height: number}}
 */
function computeImageResize({
  originWidth,
  originHeight,
  direction,
  deltaX,
  deltaY,
  shiftKey,
  aspect,
}) {
  const { signX, signY } = deltaSigns(direction);

  let width = originWidth;
  let height = originHeight;
  if (signX !== 0) {
    width = originWidth + deltaX * signX;
  }
  if (signY !== 0) {
    height = originHeight + deltaY * signY;
  }

  const locked = aspect != null && !shiftKey;
  if (locked) {
    if (signX !== 0 && signY !== 0) {
      // Corner: the axis with the larger proportional change leads.
      const widthChange = Math.abs(width - originWidth);
      const heightChange = Math.abs(height - originHeight);
      if (widthChange >= heightChange) {
        height = width / aspect;
      } else {
        width = height * aspect;
      }
    } else if (signX !== 0) {
      // Horizontal edge: width leads.
      height = width / aspect;
    } else if (signY !== 0) {
      // Vertical edge: height leads.
      width = height * aspect;
    }
  }

  return {
    width: Math.max(MIN_DIM, Math.round(width)),
    height: Math.max(MIN_DIM, Math.round(height)),
  };
}

/**
 * Absolutely-positioned overlay that paints the 8-point image resize handles +
 * the animated dashed selection ring around the rendered IMAGE element (not the
 * surrounding block chrome).
 *
 * The image marker (`[data-block-arg="<argName>"]`) sits inside the wrapped
 * block somewhere — often a small element inside a much larger cell. The overlay
 * tracks the marker's position by reading its `getBoundingClientRect` (relative
 * to the chrome's outer div) and re-evaluates on:
 *   - The marker's own ResizeObserver (size changes as the user resizes or the
 *     underlying image arg updates)
 *   - The chrome's ResizeObserver (the chrome's position shifts as siblings are
 *     added / removed / resized)
 *   - Window resize (layout reflows pinned to the viewport)
 *
 * The drag handles (`DResizeHandles`) report pointer deltas; the resize math
 * anchors to the MARKER's rect (read on drag start via `getMarkerEl`), so
 * dragging grows / shrinks the image's display size — not the chrome's.
 *
 * @typedef {Object} ImageResizeOverlayArgs
 * @property {string} blockKey
 * @property {string} argName
 * @property {() => Element|null} getChromeEl
 * @property {() => Element|null} getMarkerEl
 * @property {number|null} aspectRatio
 * @property {(dims: {width: number, height: number}) => void} onPreview
 * @property {(dims: {width: number, height: number}) => void} onCommit
 */
export default class ImageResizeOverlay extends Component {
  @service wireframeLayoutSignal;

  /**
   * The marker's rect relative to the chrome's outer div, in CSS pixels. `null`
   * means "not measured yet" (first render before the ResizeObservers fire).
   * Template-bound, so unprefixed.
   */
  @tracked rect = null;

  /** ResizeObservers on the marker and the chrome. */
  #observer = null;

  /** Bound `measure` reference for window listeners. */
  #boundMeasure = null;

  /**
   * The active resize session ({originWidth, originHeight, aspect}), or `null`.
   * Captured on `onImageResizeStart` so every move computes against a stable
   * origin rather than re-measuring the (already-previewed) marker.
   *
   * @type {?{originWidth: number, originHeight: number, aspect: ?number}}
   */
  #session = null;

  /**
   * Inline style for the overlay's outer div. Positions it absolutely inside the
   * chrome to match the marker's rect. When the rect isn't measured yet, paints
   * nothing visible.
   */
  get overlayStyle() {
    const r = this.rect;
    if (!r) {
      return trustHTML("display: none;");
    }
    return trustHTML(
      `position: absolute; top: ${r.top}px; left: ${r.left}px; ` +
        `width: ${r.width}px; height: ${r.height}px; pointer-events: none;`
    );
  }

  @action
  setup() {
    this.#boundMeasure = () => this.measure();
    this.#observer = new ResizeObserver(this.#boundMeasure);
    this.#attach();
    window.addEventListener("resize", this.#boundMeasure);
    // Bump the structural version dependency by reading it once so the next
    // layout mutation (an insert / move / arg flush) also triggers
    // re-measurement via the autotracking system.
    this.measure();
  }

  @action
  teardown() {
    this.#observer?.disconnect();
    this.#observer = null;
    if (this.#boundMeasure) {
      window.removeEventListener("resize", this.#boundMeasure);
      this.#boundMeasure = null;
    }
  }

  /**
   * Reads the marker's bounding rect relative to the chrome and stashes it on
   * the tracked `rect`. Triggers a re-render of the overlay's inline style.
   */
  @action
  measure() {
    // wireframeLayoutSignal.version is bumped on layout mutations; touching it opens a
    // tracked dep so this getter re-evaluates on those too.
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframeLayoutSignal.version;
    const marker = this.args.getMarkerEl?.();
    const chrome = this.args.getChromeEl?.();
    if (!marker || !chrome) {
      this.rect = null;
      return;
    }
    // Re-target the observer in case the marker element was replaced by a
    // re-render (e.g. uploading swapped <DLightDarkImg> from single-img to
    // picture mode).
    this.#attach();

    const markerRect = marker.getBoundingClientRect();
    const chromeRect = chrome.getBoundingClientRect();
    this.rect = {
      top: markerRect.top - chromeRect.top,
      left: markerRect.left - chromeRect.left,
      width: markerRect.width,
      height: markerRect.height,
    };
  }

  /**
   * Starts an image resize: captures the marker's current size as the origin and
   * resolves the aspect ratio (the explicit `@aspectRatio`, else the marker's
   * intrinsic ratio). Returns `false` to abort if the marker isn't resolvable.
   *
   * @returns {void|false}
   */
  @action
  onImageResizeStart() {
    const marker = this.args.getMarkerEl?.();
    if (!marker) {
      return false;
    }
    const rect = marker.getBoundingClientRect();
    const locked = this.args.aspectRatio;
    const aspect =
      typeof locked === "number" && Number.isFinite(locked) && locked > 0
        ? locked
        : rect.width / Math.max(rect.height, 1);
    this.#session = {
      originWidth: rect.width,
      originHeight: rect.height,
      aspect,
    };
  }

  /**
   * Previews the resize on each move: computes the new dimensions and hands them
   * to `@onPreview` (which paints the marker's inline size).
   *
   * @param {string} direction
   * @param {Object} dragInfo
   * @returns {void}
   */
  @action
  onImageResize(direction, dragInfo) {
    const dims = this.#computeFromDrag(direction, dragInfo);
    if (dims) {
      this.args.onPreview?.(dims);
    }
  }

  /**
   * Commits the resize on release via `@onCommit` (which clears the preview and
   * writes the image arg).
   *
   * @param {string} direction
   * @param {Object} dragInfo
   * @returns {void}
   */
  @action
  onImageResizeEnd(direction, dragInfo) {
    const dims = this.#computeFromDrag(direction, dragInfo);
    this.#session = null;
    if (dims) {
      this.args.onCommit?.(dims);
    }
  }

  /** @returns {void} */
  @action
  onImageResizeCancel() {
    this.#session = null;
  }

  #computeFromDrag(direction, dragInfo) {
    const session = this.#session;
    if (!session) {
      return null;
    }
    return computeImageResize({
      originWidth: session.originWidth,
      originHeight: session.originHeight,
      direction,
      deltaX: dragInfo.delta.x,
      deltaY: dragInfo.delta.y,
      shiftKey: dragInfo.event.shiftKey,
      aspect: session.aspect,
    });
  }

  /**
   * Re-attaches the ResizeObserver to the current marker / chrome elements. Safe
   * to call repeatedly — the observer disconnects and re-targets on each call.
   */
  #attach() {
    if (!this.#observer) {
      return;
    }
    this.#observer.disconnect();
    const marker = this.args.getMarkerEl?.();
    const chrome = this.args.getChromeEl?.();
    if (marker) {
      this.#observer.observe(marker);
    }
    if (chrome) {
      this.#observer.observe(chrome);
    }
  }

  <template>
    <div
      class="wireframe-image-resize-overlay"
      style={{this.overlayStyle}}
      {{didInsert this.setup}}
      {{willDestroy this.teardown}}
    >
      {{! Marching-ants dashed selection ring tracing the marker's edges. Pure
        CSS — animation defined in wireframe-chrome.scss. }}
      <span
        class="wireframe-image-resize-overlay__ring"
        aria-hidden="true"
      ></span>

      {{! 8 resize handles. The drag math anchors to the MARKER's rect (read on
        drag start), so dragging from any handle grows / shrinks the image's
        display size — not the chrome's. }}
      <DResizeHandles
        @handleClass="wireframe-image-resize-overlay__handle"
        @onResizeStart={{this.onImageResizeStart}}
        @onResize={{this.onImageResize}}
        @onResizeEnd={{this.onImageResizeEnd}}
        @onResizeCancel={{this.onImageResizeCancel}}
      />
    </div>
  </template>
}
