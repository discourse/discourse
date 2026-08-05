import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";

/**
 * The eight compass handles of a box resize, in clockwise order. The common
 * case (resizing a rectangle's edges + corners) — generated from `@handleClass`
 * so consumers don't repeat the list. Each handle's `payload` is its direction.
 */
const BOX_DIRECTIONS = ["n", "ne", "e", "se", "s", "sw", "w", "nw"];

/**
 * Renders a set of drag handles and wires each to the pointer-drag lifecycle,
 * dispatching normalized drag events back to the consumer. It owns the
 * boilerplate the consumers used to repeat — the handle loop, the per-handle
 * pointer wiring, and the single active-drag session — while leaving the
 * domain-specific work (units, preview, commit) to the consumer's handlers.
 *
 * Generic over what's being resized: it reports pointer geometry (origin /
 * current / delta), not pixels-vs-grid-lines-vs-fractions. The consumer's
 * `@onResize` does the math (e.g. map the pointer to a grid cell, or a px
 * delta, or a column fraction), paints its own preview, and commits on
 * `@onResizeEnd`. Only one handle drags at a time, so the session is a single
 * set of fields — no per-handle state.
 *
 * The common case — a box's 8 edge/corner handles — is built in: pass
 * `@handleClass` and the component renders the eight compass handles, each
 * classed `<handleClass> <handleClass>--<dir>` with `payload` set to the
 * direction. For anything else (e.g. N column-gutter handles at computed
 * offsets), pass explicit `@handles` descriptors as an escape hatch.
 *
 * @example
 * // Box (edges + corners) from a BEM block:
 * <DResizeHandles @handleClass="my-block__handle" @onResize={{this.onResize}} />
 *
 * @example
 * // Escape hatch — explicit descriptors:
 * <DResizeHandles @handles={{this.columnHandles}} @onResize={{this.onResize}} />
 *
 * Args:
 *  - `@handleClass` — BEM block for the built-in 8-direction box. Ignored when
 *    `@handles` is supplied.
 *  - `@directions` — optional subset of the eight compass directions to render
 *    for the built-in box (e.g. only the edges/corners that can actually move).
 *    Defaults to all eight; ignored when `@handles` is supplied.
 *  - `@handles` — explicit descriptors `{ payload, class?, style? }` (escape
 *    hatch; takes precedence over `@handleClass`). `payload` identifies the
 *    handle and is handed back to every callback; `class` positions/styles it;
 *    `style` (a plain string) is `htmlSafe`-wrapped here for inline positioning.
 *  - `@onResizeStart(payload, dragInfo)` — return `false` to veto the drag.
 *  - `@onResize(payload, dragInfo)` — fired on every move.
 *  - `@onResizeEnd(payload, dragInfo)` — fired once on release (commit here).
 *  - `@onResizeCancel(payload, dragInfo)` — fired if the gesture is cancelled.
 *  - `@draggingClass` — optional class toggled on the active handle while dragging.
 *
 * `dragInfo` = `{ payload, event, origin:{x,y}, current:{x,y}, delta:{x,y}, handleRect }`.
 */
export default class DResizeHandles extends Component {
  #activePayload = null;
  #originX = 0;
  #originY = 0;
  #handleRect = null;

  /**
   * The resolved handle descriptors: explicit `@handles` when given, otherwise
   * the built-in 8-direction box from `@handleClass`. Any string `style` is
   * `htmlSafe`-wrapped so a consumer can pass a plain inline-style string
   * without tripping the dynamic `style` XSS warning.
   *
   * @returns {Array<{payload: any, class?: string, style?: any}>}
   */
  get handles() {
    const source = this.args.handles ?? this.#boxHandles();
    return source.map((handle) => ({
      ...handle,
      style:
        typeof handle.style === "string"
          ? trustHTML(handle.style)
          : handle.style,
    }));
  }

  @action
  onHandleDown(payload, event) {
    this.#activePayload = payload;
    this.#originX = event.clientX;
    this.#originY = event.clientY;
    this.#handleRect = event.currentTarget?.getBoundingClientRect() ?? null;
    // Propagate the consumer's veto: returning false aborts the drag.
    return this.args.onResizeStart?.(payload, this.#dragInfo(event));
  }

  @action
  onHandleMove(payload, event) {
    this.args.onResize?.(payload, this.#dragInfo(event));
  }

  @action
  onHandleUp(payload, event) {
    this.args.onResizeEnd?.(payload, this.#dragInfo(event));
    this.#reset();
  }

  @action
  onHandleCancel(payload, event) {
    this.args.onResizeCancel?.(payload, this.#dragInfo(event));
    this.#reset();
  }

  #dragInfo(event) {
    return {
      payload: this.#activePayload,
      event,
      origin: { x: this.#originX, y: this.#originY },
      current: { x: event.clientX, y: event.clientY },
      delta: {
        x: event.clientX - this.#originX,
        y: event.clientY - this.#originY,
      },
      handleRect: this.#handleRect,
    };
  }

  #reset() {
    this.#activePayload = null;
    this.#handleRect = null;
  }

  #boxHandles() {
    const handleClass = this.args.handleClass;
    if (!handleClass) {
      return [];
    }
    const directions = this.args.directions ?? BOX_DIRECTIONS;
    return directions.map((dir) => ({
      payload: dir,
      class: `${handleClass} ${handleClass}--${dir}`,
    }));
  }

  <template>
    {{! Keyed by index: handles hold no cross-render state (the drag session
      lives on this component), and a payload (e.g. a column index) may repeat
      across handles, so positional keys are both safe and collision-free. }}
    {{#each this.handles key="@index" as |handle|}}
      <span
        class={{handle.class}}
        style={{handle.style}}
        data-resize-handle={{handle.payload}}
        {{dPointerDrag
          onDragStart=(fn this.onHandleDown handle.payload)
          onDrag=(fn this.onHandleMove handle.payload)
          onDragEnd=(fn this.onHandleUp handle.payload)
          onDragCancel=(fn this.onHandleCancel handle.payload)
          draggingClass=@draggingClass
        }}
      ></span>
    {{/each}}
  </template>
}
