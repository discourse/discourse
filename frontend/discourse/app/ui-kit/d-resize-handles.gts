import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { assert } from "@ember/debug";
import { registerDestructor } from "@ember/destroyable";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { isTrustedHTML, type TrustedHTML } from "@ember/template";
import dPointerDrag, {
  type DPointerDragInfo,
} from "discourse/ui-kit/modifiers/d-pointer-drag";

/** One of the eight compass directions of the built-in box resize. */
export type BoxDirection = "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw";

/**
 * The eight compass handles of a box resize, in clockwise order. The common
 * case (resizing a rectangle's edges + corners) — generated from `@handleClass`
 * so consumers don't repeat the list. Each handle's `payload` is its direction.
 */
export const BOX_DIRECTIONS: BoxDirection[] = [
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
  /**
   * What makes this handle itself. It must be unique among its siblings and
   * stable across recomputes, so that a list changing under a held pointer
   * destroys the handle that really went rather than the last one.
   *
   * Not derived from `payload`, which says what a handle means rather than which
   * one it is. Several handles can legitimately mean the same thing.
   */
  key: string;

  /** What the handle means. Handed back to every callback, and may repeat. */
  payload: Payload;

  /** Positions and styles the handle. */
  class?: string;

  /**
   * Inline positioning. Wrap the string in `trustHTML` before passing it here.
   * Only the caller knows whether the values it interpolated are safe, so this
   * component will not make that call for it.
   */
  style?: TrustedHTML;
}

/** What one gesture carries for as long as it runs. */
interface Gesture<Payload, Session> {
  payload: Payload;
  /** The element pressed, so its teardown can close this gesture. */
  handle: HTMLElement;
  /** The last report, so teardown can close the gesture at its last position. */
  event: PointerEvent;
  info: DPointerDragInfo;
  measured: Element | null;
  measuredRect: DOMRect | null;
  session: Session;
}

/**
 * The pointer geometry of a move, reported to every callback. Deliberately raw:
 * the consumer decides what a pixel delta means in its own units.
 *
 * Everything here is a snapshot of the moment it was handed over, EXCEPT
 * `session`, which is the one thing that lives for the gesture.
 */
export interface DResizeHandleDragInfo<
  Payload extends string | number,
  Session extends object = object,
> {
  /** The handle being dragged — the same value the callback's first argument carries. */
  readonly payload: Payload;

  /** The pointer event that produced this report. */
  readonly event: PointerEvent;

  /** Where the press landed, in client coordinates. */
  readonly origin: Readonly<{ x: number; y: number }>;

  /** Where the pointer is now, in client coordinates. */
  readonly current: Readonly<{ x: number; y: number }>;

  /** How far the pointer has travelled since the press. */
  readonly delta: Readonly<{ x: number; y: number }>;

  /**
   * Whether `@onResize` has fired at least once for THIS gesture. It tells a
   * resize apart from a click that landed on a handle. Commit on `@onResizeEnd`
   * only when it is set, or a bare click records a no-op change.
   */
  readonly moved: boolean;

  /**
   * Scratch for the length of one gesture, and the same object throughout it.
   *
   * Write the press-time snapshot here in `@onResizeStart` and read it back on
   * every later report. It lives here rather than on the consumer so that each
   * gesture starts with a fresh one.
   */
  readonly session: Session;

  /**
   * The element named by `@measure`, or `null` when none was named. Handed back
   * so a consumer that also needs the element itself (to paint a preview on it,
   * say) does not resolve it a second time.
   */
  readonly measured: Element | null;

  /**
   * The bounds of the element named by `@measure`, or `null` when none was
   * named. Viewport-relative, with transforms applied, so a consumer working in
   * unscaled units divides by the scale factor and subtracts `left` and `top`.
   *
   * A LIVE reading, re-read on scroll and viewport resize, so it stays correct
   * when the box moves under a held pointer. It is NOT re-read when the element
   * changes size, or on a layout shift or transform. Those raise no event.
   */
  readonly measuredRect: DOMRect | null;
}

/**
 * The box whose bounds a gesture reports: the element itself, or a function
 * receiving the pressed handle and returning it.
 */
type MeasureTarget =
  | Element
  | ((handle: HTMLElement) => Element | null | undefined);

interface DResizeHandlesSignature<
  Payload extends string | number,
  Session extends object = object,
> {
  Args: {
    /**
     * BEM block for the built-in 8-direction box. Each handle is classed
     * `<handleClass> --<dir>`. Ignored when `@handles` is supplied.
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
     * The gesture began. Snapshot the press-time state onto `dragInfo.session`
     * here. Return `false` to veto it.
     *
     * The callbacks sit in `NoInfer` positions so that `@handles` alone decides
     * the payload type. Without it a handler taking a number would infer
     * `Payload` as `number` on the built-in box, hiding a real mismatch.
     */
    onResizeStart?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>, Session>
    ) => boolean | void;

    /** Fired on every move. Compute and preview here. */
    onResize?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>, Session>
    ) => void;

    /**
     * Fired once on release, and on teardown for a gesture still held. Commit
     * here, guarded on `dragInfo.moved`.
     */
    onResizeEnd?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>, Session>
    ) => void;

    /**
     * Fired when the gesture is cancelled rather than released, teardown with a
     * gesture still held included. Mutually exclusive with `@cancelCommits`,
     * which routes cancels to `@onResizeEnd` and so leaves this one unreachable.
     */
    onResizeCancel?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>, Session>
    ) => void;

    /** A class toggled on the active handle while it is being dragged. */
    draggingClass?: string;

    /**
     * Pixels of travel before `@onResize` starts firing, to absorb the jitter of
     * a click that was never meant to be a drag.
     */
    threshold?: number;

    /**
     * Whether a gesture cut short — `pointercancel`, a lost capture, or another
     * registration claiming the pointer — reports through `@onResizeEnd` rather
     * than `@onResizeCancel`, leaving the latter unreachable.
     *
     * A consumer that commits the terminal event's position must NOT set this: a
     * cancel carries no position the user chose, so the commit would write a
     * coordinate the pointer was never at.
     */
    cancelCommits?: boolean;

    /**
     * The box being resized, so it and its bounds ride along on every report.
     * Either the element, or a function receiving the pressed handle and
     * returning it. See `measuredRect` for what is and is not re-read.
     */
    measure?: MeasureTarget;

    /**
     * Whether an accepted press stops propagating. Defaults to `false`, because
     * document-level listeners need to see `pointerdown`. Set it when the handles
     * sit inside another gesture that would otherwise steal the pointer.
     */
    stopPropagation?: boolean;
  };
}

/**
 * Renders a set of drag handles and drives each through the pointer-drag
 * lifecycle, owning what every consumer would otherwise repeat: the handle loop,
 * the per-handle pointer wiring, and one gesture's state for as long as it runs.
 *
 * It reports pointer geometry rather than a size. The consumer does the math in
 * its own units, paints its own preview, and commits on `@onResizeEnd`.
 *
 * Every gesture ends with exactly one terminal callback, whether it ends on
 * release, on its handle being removed, or on the component being destroyed.
 * Each gesture carries a `session` for press-time state.
 *
 * ONE gesture at a time. A press arriving while another is held is refused, so
 * two handles on one box can never fight over the same geometry. Two separate
 * boxes still drag at once, because each renders its own handles.
 *
 * The common case, a box's 8 edge and corner handles, is built in through
 * `@handleClass`. Anything else passes explicit `@handles` descriptors.
 *
 * @example
 * Box (edges + corners) from a BEM block:
 * ```gjs
 * <DResizeHandles @handleClass="my-block__handle" @onResize={{this.onResize}} />
 * ```
 *
 * @example
 * Escape hatch — explicit descriptors:
 * ```gjs
 * <DResizeHandles @handles={{this.columnHandles}} @onResize={{this.onResize}} />
 * ```
 *
 * `role="separator"` is wrong here and must not be used: a box resized from its
 * corners has no single value to report.
 *
 * Deliberately POINTER-ONLY. The handles are `aria-hidden` and out of the tab
 * order: eight tab stops per box would be hostile, and no ARIA role describes a
 * corner drag. Put keyboard resizing on the resized object itself.
 *
 * @see The `DResizeSeparator` component for a ONE-axis resize between two regions, which is
 *   operable by keyboard and announced.
 * @see The `dOnResize` modifier to merely OBSERVE a size change. It is not a gesture.
 */
export default class DResizeHandles<
  Payload extends string | number = BoxDirection,
  Session extends object = object,
> extends Component<DResizeHandlesSignature<Payload, Session>> {
  /** The gesture in flight, or `null` when nothing is held. */
  #gesture: Gesture<Payload, Session> | null = null;

  /**
   * Re-measures the live gesture's box.
   *
   * Bound to scroll and resize for the gesture's length because the bounds are
   * viewport-relative: the box can move under a held pointer without changing
   * size, and stale bounds put the pointer in the wrong place.
   */
  #onReflow = () => {
    if (this.#gesture) {
      this.#gesture.measuredRect =
        this.#gesture.measured?.getBoundingClientRect() ?? null;
    }
  };

  #watchingReflow = false;

  constructor(
    owner: Owner,
    args: DResizeHandlesSignature<Payload, Session>["Args"]
  ) {
    super(owner, args);
    registerDestructor(this, () => this.#closeGesture());
  }

  /**
   * The resolved handle descriptors: explicit `@handles` when named, otherwise
   * the built-in box from `@handleClass`.
   *
   * The branch tests whether `@handles` was NAMED, not whether it holds
   * anything, because naming it is what `Payload` is inferred from. Falling
   * through to the box would hand compass strings to differently-typed callbacks.
   */
  get handles() {
    const source =
      "handles" in this.args ? (this.args.handles ?? []) : this.#boxHandles();

    if (DEBUG) {
      const seen = new Set<string>();
      for (const handle of source) {
        assert(
          "DResizeHandles: wrap a descriptor's `style` in `trustHTML` before passing it",
          handle.style == null || isTrustedHTML(handle.style)
        );
        // Glimmer reports neither a missing nor a duplicate key. It derives a
        // positional one, which is what keying exists to avoid.
        assert(
          "DResizeHandles: every handle descriptor needs a unique `key`",
          handle.key != null
        );
        assert(
          `DResizeHandles: two handles share the key \`${handle.key}\``,
          !seen.has(handle.key)
        );
        seen.add(handle.key);
      }
    }

    return source;
  }

  @action
  onHandleDown(payload: Payload, event: PointerEvent, info: DPointerDragInfo) {
    // Returning false vetoes the press, so only one gesture runs at a time.
    if (this.#gesture) {
      return false;
    }

    const handle = event.currentTarget as HTMLElement;
    const measured = this.#measureTarget(handle);
    const gesture: Gesture<Payload, Session> = {
      payload,
      handle,
      event,
      info,
      measured,
      measuredRect: measured?.getBoundingClientRect() ?? null,
      session: {} as Session,
    };
    this.#gesture = gesture;
    this.#watchReflow();

    let started;
    try {
      started = this.args.onResizeStart?.(
        payload,
        this.#dragInfo(gesture, event, info)
      );
    } catch (error) {
      this.#reset();
      throw error;
    }

    // The press was vetoed, so no terminal callback will arrive to clear it.
    if (started === false) {
      this.#reset();
    }

    return started;
  }

  @action
  onHandleMove(event: PointerEvent, info: DPointerDragInfo) {
    const gesture = this.#gesture;
    if (!gesture) {
      return;
    }
    // Build the report first. `onResize?.()` skips its arguments when there is
    // no handler, and the gesture's snapshot has to update either way.
    const dragInfo = this.#dragInfo(gesture, event, info);
    this.args.onResize?.(gesture.payload, dragInfo);
  }

  @action
  onHandleUp(event: PointerEvent, info: DPointerDragInfo) {
    const gesture = this.#gesture;
    if (!gesture) {
      return;
    }
    const dragInfo = this.#dragInfo(gesture, event, info);
    // Released in a `finally` so a throwing consumer cannot strand the gesture
    // and leave the reflow listeners attached.
    try {
      this.args.onResizeEnd?.(gesture.payload, dragInfo);
    } finally {
      this.#reset();
    }
  }

  @action
  onHandleCancel(event: PointerEvent, info: DPointerDragInfo) {
    const gesture = this.#gesture;
    if (!gesture) {
      return;
    }
    const dragInfo = this.#dragInfo(gesture, event, info);
    try {
      this.args.onResizeCancel?.(gesture.payload, dragInfo);
    } finally {
      this.#reset();
    }
  }

  /**
   * Closes the gesture when the handle holding it is destroyed. That happens
   * when `@handles` or `@directions` drops a handle while the pointer is down.
   *
   * The engine reports nothing when its element goes. Without this, the consumer
   * would never get to close what it opened at the press.
   *
   * @param element - The handle being torn down.
   */
  @action
  onHandleTeardown(element: Element) {
    if (this.#gesture?.handle === element) {
      this.#closeGesture();
    }
  }

  /**
   * Ends a gesture that is still held. Runs both when a single handle is
   * destroyed and when the whole component is.
   */
  #closeGesture() {
    const gesture = this.#gesture;
    if (!gesture) {
      return;
    }
    // Clear it first. At teardown the handle and the component both close the
    // gesture, and whichever runs second has to do nothing.
    this.#reset();

    const dragInfo = {
      ...gesture.info,
      payload: gesture.payload,
      event: gesture.event,
      session: gesture.session,
      measured: gesture.measured,
      measuredRect: gesture.measuredRect,
    };
    try {
      if (this.args.cancelCommits) {
        this.args.onResizeEnd?.(gesture.payload, dragInfo);
      } else {
        this.args.onResizeCancel?.(gesture.payload, dragInfo);
      }
    } catch (error) {
      // Swallowed only here. A throw from a destructor aborts the teardown
      // flush and takes every sibling's cleanup with it.
      // eslint-disable-next-line no-console
      console.error(error);
    }
  }

  #boxHandles(): DResizeHandleDescriptor<Payload>[] {
    const handleClass = this.args.handleClass;
    if (!handleClass) {
      return [];
    }
    const directions = this.args.directions ?? BOX_DIRECTIONS;
    return directions.map((dir) => ({
      // A direction appears once in a box, so it is the handle's identity too.
      key: dir,
      // The cast is safe. Only `@handles` pins `Payload` to something else, and
      // supplying it makes this branch unreachable. TypeScript cannot see that.
      payload: dir as Payload,
      class: `${handleClass} --${dir}`,
    }));
  }

  #dragInfo(
    gesture: Gesture<Payload, Session>,
    event: PointerEvent,
    info: DPointerDragInfo
  ): DResizeHandleDragInfo<Payload, Session> {
    gesture.event = event;
    gesture.info = info;

    return {
      payload: gesture.payload,
      event,
      origin: info.origin,
      current: info.current,
      delta: info.delta,
      moved: info.moved,
      session: gesture.session,
      measured: gesture.measured,
      measuredRect: gesture.measuredRect,
    };
  }

  #reset() {
    this.#gesture = null;
    this.#unwatchReflow();
  }

  #measureTarget(handle: HTMLElement): Element | null {
    const target = this.args.measure;
    return (typeof target === "function" ? target(handle) : target) ?? null;
  }

  #watchReflow() {
    // Skip the listeners when nothing is measured, which is the common case.
    // Otherwise a document-wide scroll listener fires on every scroll for nothing.
    if (this.#watchingReflow || !this.#gesture?.measured) {
      return;
    }
    this.#watchingReflow = true;
    window.addEventListener("scroll", this.#onReflow, true);
    window.addEventListener("resize", this.#onReflow);
  }

  #unwatchReflow() {
    if (!this.#watchingReflow) {
      return;
    }
    this.#watchingReflow = false;
    window.removeEventListener("scroll", this.#onReflow, true);
    window.removeEventListener("resize", this.#onReflow);
  }

  <template>
    {{! Keyed by identity so that removing a handle destroys the right one. With
      positional keys the last handle goes instead. That strands its gesture, and
      leaves the handles after the gap bound to descriptors nobody pressed. }}
    {{#each this.handles key="key" as |handle|}}
      <span
        class={{handle.class}}
        style={{handle.style}}
        data-resize-handle={{handle.payload}}
        aria-hidden="true"
        {{willDestroy this.onHandleTeardown}}
        {{dPointerDrag
          onDragStart=(fn this.onHandleDown handle.payload)
          onDrag=this.onHandleMove
          onDragEnd=this.onHandleUp
          onDragCancel=this.onHandleCancel
          draggingClass=@draggingClass
          threshold=@threshold
          stopPropagation=@stopPropagation
          cancelCommits=@cancelCommits
        }}
      ></span>
    {{/each}}
  </template>
}
