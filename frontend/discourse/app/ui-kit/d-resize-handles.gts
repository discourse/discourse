import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { type SafeString, type TrustedHTML, trustHTML } from "@ember/template";
import dPointerDrag, {
  type DPointerDragInfo,
} from "discourse/ui-kit/modifiers/d-pointer-drag";

/** One of the eight compass directions of the built-in box resize. */
export type BoxDirection = "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw";

/**
 * The eight box handles, clockwise from the top. Each handle's payload is its
 * own direction.
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

/** One handle to draw. Pass these when your handles are not a box's edges and corners. */
export interface DResizeHandleDescriptor<Payload extends string | number> {
  /** Identifies the handle. Passed back to every callback. */
  payload: Payload;

  /** Positions and styles the handle. */
  class?: string;

  /**
   * Inline positioning. A plain string is trusted for you, so build it from your
   * own values and never from anything a user typed.
   */
  style?: string | SafeString | TrustedHTML;
}

/**
 * What each callback is told about the drag. The numbers are raw pixels; you
 * turn them into your own units.
 *
 * Every report is a fresh snapshot. Only `session` is shared across the gesture.
 */
export interface DResizeHandleDragInfo<
  Payload extends string | number,
  Session extends object = object,
> {
  /** The handle being dragged. The same value as the callback's first argument. */
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
   * True once `@onResize` has fired in this gesture. False means the user clicked
   * a handle without dragging it. Check it in `@onResizeEnd` before you save, or
   * a plain click adds an undo entry that changes nothing.
   */
  readonly moved: boolean;

  /**
   * Scratch space for one gesture, and the same object on every report.
   *
   * Store what you measured at the press in `@onResizeStart`, then read it back
   * as the drag runs. Use this instead of a field on your component: two handles
   * can be held at once, and each gesture needs its own copy.
   */
  readonly session: Session;

  /** The element from `@measure`, or `null` if you did not pass one. */
  readonly measured: Element | null;

  /**
   * The bounds of the `@measure` element, or `null` if you did not pass one.
   * Measured against the viewport with transforms applied, so divide by your
   * scale factor and subtract `left` and `top` to work in unscaled units.
   *
   * Read again when the page scrolls or the window resizes, so the box staying
   * put under a held pointer is safe. NOT read again when the box changes size,
   * so do not trust the width and height once a resize is under way.
   */
  readonly measuredRect: DOMRect | null;
}

/**
 * The box to measure: the element, or a function that takes the pressed handle
 * and returns it.
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
     * BEM block for the eight box handles. Each one gets the class
     * `<handleClass> --<dir>`. Ignored if you pass `@handles`.
     */
    handleClass?: string;

    /**
     * Which of the eight box handles to draw. Defaults to all of them. Ignored if
     * you pass `@handles`.
     */
    directions?: BoxDirection[];

    /**
     * Your own handles, for anything that is not a box. Wins over `@handleClass`.
     */
    handles?: DResizeHandleDescriptor<Payload>[];

    /**
     * The gesture started. Measure what you need and store it on
     * `dragInfo.session`. Return `false` to refuse the gesture.
     */
    onResizeStart?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>, Session>
    ) => boolean | void;

    /** Every move. Work out the new size and show it here. */
    onResize?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>, Session>
    ) => void;

    /**
     * The gesture ended, either on release or because the handles were destroyed
     * mid-drag. Save here, but only if `dragInfo.moved` is true.
     */
    onResizeEnd?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>, Session>
    ) => void;

    /**
     * The gesture was interrupted instead of released. Drop your preview without
     * saving. Never called if you set `@cancelCommits`.
     */
    onResizeCancel?: (
      payload: NoInfer<Payload>,
      dragInfo: DResizeHandleDragInfo<NoInfer<Payload>, Session>
    ) => void;

    /** A class put on the handle being dragged, and taken off at the end. */
    draggingClass?: string;

    /**
     * How far the pointer must move before `@onResize` starts, so a shaky click
     * does not count as a drag.
     */
    threshold?: number;

    /**
     * Send an interrupted gesture to `@onResizeEnd` instead of `@onResizeCancel`.
     * Set this when an interrupted resize should keep the size dragged to so far.
     *
     * Leave it off if you save the position from the final event. An interrupted
     * gesture carries no position the user chose.
     */
    cancelCommits?: boolean;

    /**
     * The box being resized. Its element and bounds then come back on every
     * report, so you do not have to find and measure it yourself. See
     * `measuredRect` for when the bounds are read again.
     */
    measure?: MeasureTarget;

    /**
     * Stop an accepted press from bubbling. Off by default, because listeners on
     * the document need to see `pointerdown`. Turn it on when the handles sit
     * inside another drag gesture, which would otherwise take the pointer and end
     * yours as soon as it starts.
     */
    stopPropagation?: boolean;
  };
}

/**
 * Draws a set of drag handles and runs the pointer gesture for each one.
 *
 * The handles do not resize anything. They report how far the pointer has moved,
 * and you do the rest: work out the new size in your own units in `@onResize`,
 * show it, then save it in `@onResizeEnd`. Each gesture carries a `session`
 * object to hold whatever you measured at the press.
 *
 * For a box, pass `@handleClass` and you get eight handles, one per edge and
 * corner. For anything else, pass your own `@handles`.
 *
 * Every gesture ends with exactly one call to `@onResizeEnd` or
 * `@onResizeCancel`, including when the handles are destroyed mid-drag. The one
 * exception is the gap noted below.
 *
 * @example
 * The eight box handles, from a BEM block:
 * ```gjs
 * <DResizeHandles @handleClass="my-block__handle" @onResize={{this.onResize}} />
 * ```
 *
 * @example
 * Your own handles:
 * ```gjs
 * <DResizeHandles @handles={{this.columnHandles}} @onResize={{this.onResize}} />
 * ```
 *
 * Pointer only. The handles are hidden from assistive technology and cannot be
 * tabbed to, because eight tab stops per box would be painful and no ARIA role
 * describes dragging a corner. Put keyboard support on the object being resized,
 * where you know what its units mean. Do not add `role="separator"` either: a box
 * dragged by its corners has no single value to report.
 *
 * Known gap: if `@handles` or `@directions` gets shorter during a gesture, the
 * last handle is destroyed rather than the one that went away. A gesture held on
 * it then ends with no callback at all.
 *
 * @see `DResizeSeparator` to resize along one axis, between two regions. It works
 *   by keyboard and is announced.
 * @see The `dOnResize` modifier to watch a size change rather than drive one.
 */
export default class DResizeHandles<
  Payload extends string | number = BoxDirection,
  Session extends object = object,
> extends Component<DResizeHandlesSignature<Payload, Session>> {
  // Live gestures, keyed by pointer. Every handle shares these handlers, so the
  // pointer id is the only thing that tells two simultaneous drags apart.
  #gestures = new Map<
    number,
    {
      payload: Payload;
      /** The last report, so teardown can end the gesture where it stopped. */
      event: PointerEvent;
      info: DPointerDragInfo;
      measured: Element | null;
      measuredRect: DOMRect | null;
      session: Session;
    }
  >();

  // Bounds are measured against the viewport, so a scroll moves the box without
  // resizing it. Stale bounds would put the pointer in the wrong place.
  #onReflow = () => {
    for (const gesture of this.#gestures.values()) {
      gesture.measuredRect = gesture.measured?.getBoundingClientRect() ?? null;
    }
  };

  #watchingReflow = false;

  constructor(
    owner: Owner,
    args: DResizeHandlesSignature<Payload, Session>["Args"]
  ) {
    super(owner, args);
    registerDestructor(this, () => this.#closeHeldGestures());
  }

  /**
   * The handles to draw: `@handles` if it was passed at all, otherwise the box
   * from `@handleClass`. Passing `@handles` counts even when it is empty, so a
   * consumer whose list is briefly undefined gets no handles rather than the
   * eight box ones, which would carry the wrong payloads.
   */
  get handles() {
    const source =
      "handles" in this.args ? (this.args.handles ?? []) : this.#boxHandles();
    return source.map((handle) => ({
      ...handle,
      style:
        typeof handle.style === "string"
          ? trustHTML(handle.style)
          : handle.style,
    }));
  }

  @action
  onHandleDown(payload: Payload, event: PointerEvent, info: DPointerDragInfo) {
    const measured = this.#measureTarget(event.currentTarget as HTMLElement);
    this.#gestures.set(event.pointerId, {
      payload,
      event,
      info,
      measured,
      measuredRect: measured?.getBoundingClientRect() ?? null,
      session: {} as Session,
    });
    this.#watchReflow();

    let started;
    try {
      started = this.args.onResizeStart?.(
        payload,
        this.#dragInfo(payload, event, info)
      );
    } catch (error) {
      this.#reset(event);
      throw error;
    }

    // A refused press starts no gesture, so nothing later would clean this up.
    if (started === false) {
      this.#reset(event);
    }

    return started;
  }

  @action
  onHandleMove(payload: Payload, event: PointerEvent, info: DPointerDragInfo) {
    this.args.onResize?.(payload, this.#dragInfo(payload, event, info));
  }

  @action
  onHandleUp(payload: Payload, event: PointerEvent, info: DPointerDragInfo) {
    // In a `finally`, so a callback that throws still releases the gesture and its
    // scroll listeners.
    try {
      this.args.onResizeEnd?.(payload, this.#dragInfo(payload, event, info));
    } finally {
      this.#reset(event);
    }
  }

  @action
  onHandleCancel(
    payload: Payload,
    event: PointerEvent,
    info: DPointerDragInfo
  ) {
    try {
      this.args.onResizeCancel?.(payload, this.#dragInfo(payload, event, info));
    } finally {
      this.#reset(event);
    }
  }

  /**
   * Ends any gesture still being held as the component goes away. The gesture
   * layer says nothing on teardown, so without this a consumer that opened
   * something at the press would never be told to close it.
   */
  #closeHeldGestures() {
    const held = [...this.#gestures.values()];
    this.#gestures.clear();
    this.#unwatchReflow();

    for (const gesture of held) {
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
        // Only swallowed here. This runs while every sibling component is being
        // destroyed, and throwing would stop their cleanup too.
        // eslint-disable-next-line no-console
        console.error(error);
      }
    }
  }

  #boxHandles(): DResizeHandleDescriptor<Payload>[] {
    const handleClass = this.args.handleClass;
    if (!handleClass) {
      return [];
    }
    const directions = this.args.directions ?? BOX_DIRECTIONS;
    return directions.map((dir) => ({
      // Reaching here means `@handles` was not passed, so `Payload` is a compass
      // direction. TypeScript cannot see that on its own.
      payload: dir as Payload,
      class: `${handleClass} --${dir}`,
    }));
  }

  #dragInfo(
    payload: Payload,
    event: PointerEvent,
    info: DPointerDragInfo
  ): DResizeHandleDragInfo<Payload, Session> {
    const gesture = this.#gestures.get(event.pointerId);
    if (gesture) {
      gesture.event = event;
      gesture.info = info;
    }

    return {
      // The callback's payload, not the one saved at the press. If the handle list
      // changes mid-drag the handler is rebound, and this follows it.
      payload,
      event,
      origin: info.origin,
      current: info.current,
      delta: info.delta,
      moved: info.moved,
      session: gesture?.session ?? ({} as Session),
      measured: gesture?.measured ?? null,
      measuredRect: gesture?.measuredRect ?? null,
    };
  }

  #reset(event: PointerEvent) {
    this.#gestures.delete(event.pointerId);
    // Dropped once nothing is left to measure, which is not the same as no
    // gesture being left: a gesture without `@measure` can outlive one with it.
    if (!this.#hasMeasuredGesture()) {
      this.#unwatchReflow();
    }
  }

  #hasMeasuredGesture(): boolean {
    for (const gesture of this.#gestures.values()) {
      if (gesture.measured) {
        return true;
      }
    }
    return false;
  }

  #measureTarget(handle: HTMLElement): Element | null {
    const target = this.args.measure;
    return (typeof target === "function" ? target(handle) : target) ?? null;
  }

  #watchReflow() {
    // Without `@measure` there is nothing to re-measure, and that is the common
    // case. Listening anyway would run on every scroll in the page to do nothing.
    if (this.#watchingReflow || !this.#hasMeasuredGesture()) {
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
    {{! Keyed by index. The handles hold no state of their own, and two of them may
      share a payload, so the index is the only safe key. }}
    {{#each this.handles key="@index" as |handle|}}
      <span
        class={{handle.class}}
        style={{handle.style}}
        data-resize-handle={{handle.payload}}
        aria-hidden="true"
        {{dPointerDrag
          onDragStart=(fn this.onHandleDown handle.payload)
          onDrag=(fn this.onHandleMove handle.payload)
          onDragEnd=(fn this.onHandleUp handle.payload)
          onDragCancel=(fn this.onHandleCancel handle.payload)
          draggingClass=@draggingClass
          threshold=@threshold
          stopPropagation=@stopPropagation
          cancelCommits=@cancelCommits
        }}
      ></span>
    {{/each}}
  </template>
}
