import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { type TrustedHTML, trustHTML } from "@ember/template";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import type WireframeLayoutSignalService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-signal";

const MIN_DIM = 40;

type ResizeDirection = "nw" | "n" | "ne" | "e" | "se" | "s" | "sw" | "w";

type DeltaSigns = {
  /** Multiplier applied to horizontal pointer movement. */
  signX: -1 | 0 | 1;
  /** Multiplier applied to vertical pointer movement. */
  signY: -1 | 0 | 1;
};

type ImageDimensions = {
  /** Image width in CSS pixels. */
  width: number;
  /** Image height in CSS pixels. */
  height: number;
};

type ImageResizeParams = {
  /** Resize handle being dragged. */
  direction: ResizeDirection;
  /** Horizontal pointer displacement. */
  deltaX: number;
  /** Vertical pointer displacement. */
  deltaY: number;
  /** Whether aspect locking is released. */
  shiftKey: boolean;
  /** Locked aspect ratio, or `null` when unavailable. */
  aspect: number | null;
  /** Origin image width in CSS pixels. */
  originWidth: number;
  /** Origin image height in CSS pixels. */
  originHeight: number;
};

type ResizeDragInfo = {
  /** Pointer event driving the resize. */
  event: MouseEvent;
  /** Pointer displacement from resize start. */
  delta: {
    /** Horizontal displacement. */
    x: number;
    /** Vertical displacement. */
    y: number;
  };
};

type OverlayRect = ImageDimensions & {
  /** Vertical offset from the block chrome. */
  top: number;
  /** Horizontal offset from the block chrome. */
  left: number;
};

type ImageResizeSession = {
  /** Origin image width in CSS pixels. */
  originWidth: number;
  /** Origin image height in CSS pixels. */
  originHeight: number;
  /** Aspect ratio locked for this session. */
  aspect: number | null;
};

interface ImageResizeOverlaySignature {
  /** Image geometry resolvers and resize callbacks. */
  Args: {
    /** Composite key of the block whose image is resized. */
    blockKey: string;
    /** Name of the image argument being resized. */
    argName: string;
    /** Resolves the containing block chrome. */
    getChromeEl: () => Element | null;
    /** Resolves the rendered image marker. */
    getMarkerEl: () => Element | null;
    /** Explicit aspect ratio, or `null` to derive it from the marker. */
    aspectRatio: number | null;
    /** Paints preview dimensions without committing. */
    onPreview: (
      /** Preview image dimensions. */
      dimensions: ImageDimensions
    ) => void;
    /** Commits final image dimensions. */
    onCommit: (
      /** Final image dimensions. */
      dimensions: ImageDimensions
    ) => void;
  };
}

/**
 * Resolves the active axes for a compass direction. `signX` / `signY` translate
 * a raw pointer delta into a width / height delta (dragging the `w` edge LEFT
 * grows the width, so `signX` is `-1` for `w`). A `0` axis means that edge
 * doesn't move (so the dimension is held).
 *
 * @param direction - One of `nw|n|ne|e|se|s|sw|w`.
 * @returns Signed multipliers for both axes.
 */
function deltaSigns(direction: ResizeDirection): DeltaSigns {
  let signX: DeltaSigns["signX"] = 0;
  let signY: DeltaSigns["signY"] = 0;
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
 * @param params - Resize origin and current pointer displacement.
 *   - `originWidth` - Origin image width.
 *   - `originHeight` - Origin image height.
 *   - `direction` - Resize handle being dragged.
 *   - `deltaX` - Raw horizontal pointer delta.
 *   - `deltaY` - Raw vertical pointer delta.
 *   - `shiftKey` - Whether to release the aspect lock.
 *   - `aspect` - Locked aspect ratio, or `null`.
 * @returns Resized image dimensions.
 */
function computeImageResize({
  originWidth,
  originHeight,
  direction,
  deltaX,
  deltaY,
  shiftKey,
  aspect,
}: ImageResizeParams): ImageDimensions {
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
 */
export default class ImageResizeOverlay extends Component<ImageResizeOverlaySignature> {
  /** Invalidates measurements after layout changes. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  /**
   * The marker's rect relative to the chrome's outer div, in CSS pixels. `null`
   * means "not measured yet" (first render before the ResizeObservers fire).
   * Template-bound, so unprefixed.
   */
  @tracked rect: OverlayRect | null = null;

  /** ResizeObservers on the marker and the chrome. */
  #observer: ResizeObserver | null = null;

  /** Bound `measure` reference for window listeners. */
  #boundMeasure: (() => void) | null = null;

  /**
   * The active resize session (`{originWidth, originHeight, aspect}`), or `null`.
   * Captured on `onImageResizeStart` so every move computes against a stable
   * origin rather than re-measuring the (already-previewed) marker.
   *
   */
  #session: ImageResizeSession | null = null;

  /**
   * Inline style for the overlay's outer div. Positions it absolutely inside the
   * chrome to match the marker's rect. When the rect isn't measured yet, paints
   * nothing visible.
   */
  get overlayStyle(): TrustedHTML {
    const r = this.rect;
    if (!r) {
      return trustHTML("display: none;");
    }
    return trustHTML(
      `position: absolute; top: ${r.top}px; left: ${r.left}px; ` +
        `width: ${r.width}px; height: ${r.height}px; pointer-events: none;`
    );
  }

  /** Installs measurement observers and viewport listeners. */
  @action
  setup(): void {
    this.#boundMeasure = () => this.measure();
    this.#observer = new ResizeObserver(this.#boundMeasure);
    this.#attach();
    window.addEventListener("resize", this.#boundMeasure);
    // Bump the structural version dependency by reading it once so the next
    // layout mutation (an insert / move / arg flush) also triggers
    // re-measurement via the autotracking system.
    this.measure();
  }

  /** Disconnects measurement observers and viewport listeners. */
  @action
  teardown(): void {
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
  measure(): void {
    // wireframeLayoutSignal.version is bumped on layout mutations; touching it opens a
    // tracked dep so this getter re-evaluates on those too.
    void this.wireframeLayoutSignal.version;
    const marker = this.args.getMarkerEl();
    const chrome = this.args.getChromeEl();
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
   * @returns `false` when the marker is unavailable, otherwise nothing.
   */
  @action
  onImageResizeStart(): void | false {
    const marker = this.args.getMarkerEl();
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
   * @param direction - Resize handle being dragged.
   * @param dragInfo - Pointer displacement for the resize.
   */
  @action
  onImageResize(direction: ResizeDirection, dragInfo: ResizeDragInfo): void {
    const dims = this.#computeFromDrag(direction, dragInfo);
    if (dims) {
      this.args.onPreview(dims);
    }
  }

  /**
   * Commits the resize on release via `@onCommit` (which clears the preview and
   * writes the image arg).
   *
   * @param direction - Resize handle being dragged.
   * @param dragInfo - Pointer displacement for the resize.
   */
  @action
  onImageResizeEnd(direction: ResizeDirection, dragInfo: ResizeDragInfo): void {
    const dims = this.#computeFromDrag(direction, dragInfo);
    this.#session = null;
    if (dims) {
      this.args.onCommit(dims);
    }
  }

  /** Cancels the active resize session. */
  @action
  onImageResizeCancel(): void {
    this.#session = null;
  }

  /**
   * Computes dimensions from the active resize session.
   *
   * @param direction - Resize handle being dragged.
   * @param dragInfo - Pointer displacement for the resize.
   * @returns Resized dimensions, or `null` without an active session.
   */
  #computeFromDrag(
    direction: ResizeDirection,
    dragInfo: ResizeDragInfo
  ): ImageDimensions | null {
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
  #attach(): void {
    if (!this.#observer) {
      return;
    }
    this.#observer.disconnect();
    const marker = this.args.getMarkerEl();
    const chrome = this.args.getChromeEl();
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
