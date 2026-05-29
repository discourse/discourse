// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";
import blockResizeDrag from "../../modifiers/block-resize-drag";

/**
 * Absolutely-positioned overlay that paints the 8-point image resize
 * handles + the animated dashed selection ring around the rendered
 * IMAGE element (not the surrounding block chrome).
 *
 * The image marker (`[data-block-arg="<argName>"]`) sits inside the
 * wrapped block somewhere — often as a small element inside a much
 * larger cell. The overlay tracks the marker's position by reading
 * its `getBoundingClientRect` (relative to the chrome's outer div)
 * and re-evaluates on:
 *   - The marker's own ResizeObserver (size changes as the user
 *     resizes or the underlying image arg updates)
 *   - The chrome's ResizeObserver (the chrome's position shifts as
 *     siblings are added / removed / resized)
 *   - Window resize (layout reflows pinned to the viewport)
 *
 * Drag handles read `getBoundingClientRect` of the MARKER element
 * directly (passed via `getMarkerEl`) so the resize math is anchored
 * to the actual image, not to this overlay's own position.
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
  @service wireframe;

  /**
   * The marker's rect relative to the chrome's outer div, in CSS
   * pixels. `null` means "not measured yet" (first render before the
   * ResizeObservers fire). Template-bound, so unprefixed.
   */
  @tracked rect = null;

  /** ResizeObservers on the marker and the chrome. */
  #observer = null;

  /** Bound `measure` reference for window listeners. */
  #boundMeasure = null;

  /**
   * Inline style for the overlay's outer div. Positions it absolutely
   * inside the chrome to match the marker's rect. When the rect isn't
   * measured yet, paints nothing visible.
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
    // Bump the structural version dependency by reading it once so
    // the next layout mutation (an insert / move / arg flush) also
    // triggers re-measurement via the autotracking system.
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
   * Reads the marker's bounding rect relative to the chrome and
   * stashes it on the tracked `rect`. Triggers a re-render of the
   * overlay's inline style.
   */
  @action
  measure() {
    // structuralVersion is bumped on layout mutations; touching it
    // opens a tracked dep so this getter re-evaluates on those too.
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const marker = this.args.getMarkerEl?.();
    const chrome = this.args.getChromeEl?.();
    if (!marker || !chrome) {
      this.rect = null;
      return;
    }
    // Re-target the observer in case the marker element was replaced
    // by a re-render (e.g. uploading swapped <DLightDarkImg> from
    // single-img to picture mode).
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
   * Re-attaches the ResizeObserver to the current marker / chrome
   * elements. Safe to call repeatedly — the observer disconnects and
   * re-targets on each call.
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
      {{! Marching-ants dashed selection ring tracing the marker's
        edges. Pure CSS — animation defined in wireframe-chrome.scss. }}
      <span
        class="wireframe-image-resize-overlay__ring"
        aria-hidden="true"
      ></span>

      {{! 8 resize handles. Each binds the shared drag modifier with
        its own compass direction. The drag math anchors to the
        MARKER's rect (via getMarkerEl), so dragging from any handle
        grows / shrinks the image's display size — not the chrome's. }}
      <span
        class="wireframe-image-resize-overlay__handle wireframe-image-resize-overlay__handle--nw"
        title={{i18n "wireframe.canvas.image_resize_title"}}
        aria-hidden="true"
        {{blockResizeDrag @getMarkerEl "nw" @aspectRatio @onPreview @onCommit}}
      ></span>
      <span
        class="wireframe-image-resize-overlay__handle wireframe-image-resize-overlay__handle--n"
        title={{i18n "wireframe.canvas.image_resize_title"}}
        aria-hidden="true"
        {{blockResizeDrag @getMarkerEl "n" @aspectRatio @onPreview @onCommit}}
      ></span>
      <span
        class="wireframe-image-resize-overlay__handle wireframe-image-resize-overlay__handle--ne"
        title={{i18n "wireframe.canvas.image_resize_title"}}
        aria-hidden="true"
        {{blockResizeDrag @getMarkerEl "ne" @aspectRatio @onPreview @onCommit}}
      ></span>
      <span
        class="wireframe-image-resize-overlay__handle wireframe-image-resize-overlay__handle--e"
        title={{i18n "wireframe.canvas.image_resize_title"}}
        aria-hidden="true"
        {{blockResizeDrag @getMarkerEl "e" @aspectRatio @onPreview @onCommit}}
      ></span>
      <span
        class="wireframe-image-resize-overlay__handle wireframe-image-resize-overlay__handle--se"
        title={{i18n "wireframe.canvas.image_resize_title"}}
        aria-hidden="true"
        {{blockResizeDrag @getMarkerEl "se" @aspectRatio @onPreview @onCommit}}
      ></span>
      <span
        class="wireframe-image-resize-overlay__handle wireframe-image-resize-overlay__handle--s"
        title={{i18n "wireframe.canvas.image_resize_title"}}
        aria-hidden="true"
        {{blockResizeDrag @getMarkerEl "s" @aspectRatio @onPreview @onCommit}}
      ></span>
      <span
        class="wireframe-image-resize-overlay__handle wireframe-image-resize-overlay__handle--sw"
        title={{i18n "wireframe.canvas.image_resize_title"}}
        aria-hidden="true"
        {{blockResizeDrag @getMarkerEl "sw" @aspectRatio @onPreview @onCommit}}
      ></span>
      <span
        class="wireframe-image-resize-overlay__handle wireframe-image-resize-overlay__handle--w"
        title={{i18n "wireframe.canvas.image_resize_title"}}
        aria-hidden="true"
        {{blockResizeDrag @getMarkerEl "w" @aspectRatio @onPreview @onCommit}}
      ></span>
    </div>
  </template>
}
