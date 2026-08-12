import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { type SafeString, type TrustedHTML, trustHTML } from "@ember/template";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";

/** One of the eight compass directions of the built-in box resize. */
type BoxDirection = "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw";

/**
 * The eight compass handles of a box resize, in clockwise order. The common
 * case (resizing a rectangle's edges + corners) — generated from `@handleClass`
 * so consumers don't repeat the list. Each handle's `payload` is its direction.
 */
const BOX_DIRECTIONS: BoxDirection[] = [
  "n",
  "ne",
  "e",
  "se",
  "s",
  "sw",
  "w",
  "nw",
];

/**
 * One handle to render. The escape hatch from the built-in box: supply these
 * when the handles are not a rectangle's edges and corners.
 */
export interface DResizeHandleDescriptor<Payload extends string | number> {
  /** Identifies the handle. Handed back to every callback. */
  payload: Payload;

  /** Positions and styles the handle. */
  class?: string;

  /**
   * Inline positioning. A plain string is wrapped here, so a consumer can pass
   * one without tripping the dynamic-`style` XSS warning.
   */
  style?: string | SafeString | TrustedHTML;
}

/**
 * The pointer geometry of a move, reported to every callback. Deliberately raw:
 * the consumer decides what a pixel delta means in its own units.
 */
export interface DResizeHandleDragInfo<Payload extends string | number> {
  /** The handle being dragged — the same value the callback's first argument carries. */
  payload: Payload;

  /** The pointer event that produced this report. */
  event: PointerEvent;

  /** Where the press landed, in client coordinates. */
  origin: { x: number; y: number };

  /** Where the pointer is now, in client coordinates. */
  current: { x: number; y: number };

  /** How far the pointer has travelled since the press. */
  delta: { x: number; y: number };

  /** The handle's own bounds at press time, or `null` if they were unreadable. */
  handleRect: DOMRect | null;
}

interface DResizeHandlesSignature<Payload extends string | number> {
  Args: {
    /**
     * BEM block for the built-in 8-direction box. Each handle is classed
     * `<handleClass> <handleClass>--<dir>`. Ignored when `@handles` is supplied.
     */
    handleClass?: string;

    /**
     * A subset of the eight compass directions to render for the built-in box
     * (e.g. only the edges and corners that can actually move). Defaults to all
     * eight; ignored when `@handles` is supplied.
     */
    directions?: BoxDirection[];

    /**
     * Explicit handle descriptors. The escape hatch for anything that is not a
     * box — N column-gutter handles at computed offsets, say. Takes precedence
     * over `@handleClass`.
     */
    handles?: DResizeHandleDescriptor<Payload>[];

    /**
     * The gesture began. Return `false` to veto it.
     *
     * The callbacks are `NoInfer` positions so the payload type is decided by
     * `@handles` alone. Otherwise a handler taking, say, a number would infer
     * `Payload` as `number` on the built-in box, which hands back compass
     * strings — the mismatch would be hidden instead of reported.
     */
    onResizeStart?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>>
    ) => boolean | void;

    /** Fired on every move. Compute and preview here. */
    onResize?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>>
    ) => void;

    /** Fired once on release. Commit here. */
    onResizeEnd?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>>
    ) => void;

    /** Fired when the gesture is cancelled rather than released. */
    onResizeCancel?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>>
    ) => void;

    /** A class toggled on the active handle while it is being dragged. */
    draggingClass?: string;

    /**
     * Pixels of travel before `@onResize` starts firing, to absorb the jitter of
     * a click that was never meant to be a drag.
     */
    threshold?: number;

    /**
     * Whether an accepted press stops propagating. Defaults to `false`, since
     * document-level listeners depend on seeing `pointerdown`. Required when the
     * handles sit inside another gesture: the press bubbles, the enclosing
     * element claims the pointer last and so wins it, and the handle would be
     * released the instant it was pressed.
     */
    stopPropagation?: boolean;
  };
}

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
 * `@onResizeEnd`. Each handle drags independently, and a touch screen can hold
 * two at once, so what a gesture was pressed at is tracked per pointer.
 *
 * The common case — a box's 8 edge/corner handles — is built in: pass
 * `@handleClass` and the component renders the eight compass handles, each
 * classed `<handleClass> <handleClass>--<dir>` with `payload` set to the
 * direction. For anything else (e.g. N column-gutter handles at computed
 * offsets), pass explicit `@handles` descriptors as an escape hatch.
 *
 * @example
 * ```gjs
 * // Box (edges + corners) from a BEM block:
 * <DResizeHandles @handleClass="my-block__handle" @onResize={{this.onResize}} />
 * ```
 *
 * @example
 * ```gjs
 * // Escape hatch — explicit descriptors:
 * <DResizeHandles @handles={{this.columnHandles}} @onResize={{this.onResize}} />
 * ```
 *
 * This is the TWO-dimensional shape. `role="separator"` is wrong here and must not
 * be used: a box resized from its corners has no single value to report.
 *
 * Guide to choosing between the gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 *
 * @see The `DResizeSeparator` component for a ONE-axis resize between two regions, which is
 *   operable by keyboard and announced.
 * @see The `dOnResize` modifier to merely OBSERVE a size change. It is not a gesture.
 */
export default class DResizeHandles<
  Payload extends string | number = BoxDirection,
> extends Component<DResizeHandlesSignature<Payload>> {
  /**
   * What each in-flight gesture was pressed at, keyed by its pointer.
   *
   * Per pointer rather than per component: every handle registers its own
   * gesture, and the engine keeps concurrent pointers alive, so two fingers on
   * two handles of the same box would otherwise share and overwrite one origin.
   */
  #sessions = new Map<
    number,
    { originX: number; originY: number; handleRect: DOMRect | null }
  >();

  /**
   * The resolved handle descriptors: explicit `@handles` when given, otherwise
   * the built-in 8-direction box from `@handleClass`. Any string `style` is
   * wrapped so a consumer can pass a plain inline-style string without tripping
   * the dynamic `style` XSS warning.
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
  onHandleDown(payload: Payload, event: PointerEvent) {
    this.#sessions.set(event.pointerId, {
      originX: event.clientX,
      originY: event.clientY,
      handleRect:
        (event.currentTarget as HTMLElement | null)?.getBoundingClientRect() ??
        null,
    });
    // Propagate the consumer's veto: returning false aborts the drag.
    const started = this.args.onResizeStart?.(
      payload,
      this.#dragInfo(payload, event)
    );

    // A vetoed press starts no gesture, so no terminal callback arrives to
    // close it and the session would otherwise describe a drag that never
    // happened.
    if (started === false) {
      this.#reset(event);
    }

    return started;
  }

  @action
  onHandleMove(payload: Payload, event: PointerEvent) {
    this.args.onResize?.(payload, this.#dragInfo(payload, event));
  }

  @action
  onHandleUp(payload: Payload, event: PointerEvent) {
    this.args.onResizeEnd?.(payload, this.#dragInfo(payload, event));
    this.#reset(event);
  }

  @action
  onHandleCancel(payload: Payload, event: PointerEvent) {
    this.args.onResizeCancel?.(payload, this.#dragInfo(payload, event));
    this.#reset(event);
  }

  #dragInfo(
    payload: Payload,
    event: PointerEvent
  ): DResizeHandleDragInfo<Payload> {
    const session = this.#sessions.get(event.pointerId);
    const originX = session?.originX ?? event.clientX;
    const originY = session?.originY ?? event.clientY;

    return {
      // The callback's own payload rather than the session snapshot: with
      // positional keys, a descriptor list that changes mid-drag rebinds the
      // handler while the snapshot still holds what was pressed.
      payload,
      event,
      origin: { x: originX, y: originY },
      current: { x: event.clientX, y: event.clientY },
      delta: {
        x: event.clientX - originX,
        y: event.clientY - originY,
      },
      handleRect: session?.handleRect ?? null,
    };
  }

  #reset(event: PointerEvent) {
    this.#sessions.delete(event.pointerId);
  }

  #boxHandles(): DResizeHandleDescriptor<Payload>[] {
    const handleClass = this.args.handleClass;
    if (!handleClass) {
      return [];
    }
    const directions = this.args.directions ?? BOX_DIRECTIONS;
    return directions.map((dir) => ({
      // Only `@handles` can pin `Payload` to something other than a compass
      // direction, and supplying it makes this branch unreachable — the getter
      // above prefers the descriptors. TypeScript cannot correlate the two.
      payload: dir as Payload,
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
          threshold=@threshold
          stopPropagation=@stopPropagation
        }}
      ></span>
    {{/each}}
  </template>
}
