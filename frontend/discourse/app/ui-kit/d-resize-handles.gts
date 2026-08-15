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
   * Whether `@onResize` has fired at least once for THIS gesture, which is what
   * tells a resize apart from a click that landed on a handle. Commit on
   * `@onResizeEnd` only when it is set, or a bare click writes an entry into
   * whatever history the commit feeds.
   */
  readonly moved: boolean;

  /**
   * Scratch for the length of one gesture, and the same object throughout it.
   *
   * Per gesture rather than per component because every handle registers its
   * own, and a touch screen can hold two at once: state hung on the consumer
   * would be rebased the moment the second pressed. Write the press-time
   * snapshot here in `@onResizeStart` and read it back on every later report.
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
   * named. In CSS pixels relative to the viewport, with the element's own
   * transform and its ancestors' already applied. Under a uniform, unrotated
   * scale that means `width` and `height` come back scaled and a consumer
   * working in unscaled units divides them by that factor; `left` and `top` are
   * viewport positions, so a translation has to come off before they mean
   * anything in the consumer's own space.
   *
   * A LIVE reading, not a frozen one: taken at the press and re-read on scroll
   * and viewport resize, so a consumer projecting the pointer into the box's
   * own space (which grid cell is under the pointer) stays correct when the box
   * moves under a held pointer. It is not re-read when the element merely
   * changes SIZE, nor on a layout shift, transform or transition, none of which
   * raise either event.
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
     * The callbacks are `NoInfer` positions so the payload type is decided by
     * `@handles` alone. Otherwise a handler taking, say, a number would infer
     * `Payload` as `number` on the built-in box, which hands back compass
     * strings — the mismatch would be hidden instead of reported.
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
     * Whether a gesture cut short reports through `@onResizeEnd` rather than
     * `@onResizeCancel`, which leaves the latter unreachable. Cut short covers
     * more than the OS taking the pointer: losing the capture, and another
     * registration claiming the same pointer, arrive the same way.
     *
     * Reach for it only when the two would do the same thing. A consumer that
     * commits the terminal event's position must NOT set this: a cancel carries
     * no position the user chose, so the commit would write a coordinate the
     * pointer was never at. Handle the two separately instead.
     */
    cancelCommits?: boolean;

    /**
     * The box being resized, so it and its bounds ride along on every report.
     * Either the element, or a function receiving the pressed handle and
     * returning it.
     *
     * Without this a consumer that projects the pointer into the box's own
     * space has to resolve the element, measure it at the press and re-measure
     * it on scroll itself, which is the bookkeeping this component exists to
     * own. See `measuredRect` for what is and is not re-read.
     */
    measure?: MeasureTarget;

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
 * Renders a set of drag handles and drives each through the pointer-drag
 * lifecycle, owning what every consumer would otherwise repeat: the handle loop,
 * the per-handle pointer wiring, and one gesture's state for as long as it runs.
 *
 * It reports pointer geometry rather than a size, so the consumer's `@onResize`
 * does the math in whatever units it thinks in, paints its own preview, and
 * commits on `@onResizeEnd`. Every gesture gets exactly one terminal callback,
 * teardown included, and each carries a `session` to hang press-time state on.
 *
 * The common case — a box's 8 edge/corner handles — is built in through
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
 * order, because eight tab stops per box would be hostile and no ARIA role
 * describes a corner drag. Keyboard operation belongs on the resized object
 * itself, where the consumer knows what its units mean.
 *
 * Known gap: shrinking `@handles` or `@directions` mid-gesture destroys the LAST
 * handle, since they are keyed positionally, stranding a gesture held on it with
 * no terminal callback.
 *
 * @see The `DResizeSeparator` component for a ONE-axis resize between two regions, which is
 *   operable by keyboard and announced.
 * @see The `dOnResize` modifier to merely OBSERVE a size change. It is not a gesture.
 */
export default class DResizeHandles<
  Payload extends string | number = BoxDirection,
  Session extends object = object,
> extends Component<DResizeHandlesSignature<Payload, Session>> {
  /**
   * The in-flight gestures, keyed by pointer.
   *
   * Keyed rather than held singly because every handle registers its own
   * gesture and the engine keeps concurrent pointers alive, while these handlers
   * are shared across all of them: two fingers on two handles of one box arrive
   * here indistinguishable but for the pointer they came on.
   */
  #gestures = new Map<
    number,
    {
      payload: Payload;
      /** The last report, so teardown can close the gesture where it stood. */
      event: PointerEvent;
      info: DPointerDragInfo;
      measured: Element | null;
      measuredRect: DOMRect | null;
      session: Session;
    }
  >();

  /**
   * Re-measures every live gesture's box.
   *
   * Bound to scroll and resize for the length of a gesture because the reported
   * bounds are viewport-relative: the box can move under a held pointer without
   * changing size, and a consumer hit-testing against stale bounds would place
   * the pointer in the wrong cell.
   */
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
   * The resolved handle descriptors: explicit `@handles` when named, otherwise
   * the built-in 8-direction box from `@handleClass`. Any string `style` is
   * wrapped so a consumer can pass a plain inline-style string without tripping
   * the dynamic `style` XSS warning.
   *
   * Keyed on whether `@handles` was NAMED rather than on whether it holds
   * anything, because that is the condition `Payload` is inferred from. A
   * consumer whose descriptors are momentarily undefined has callbacks typed for
   * its own payload, and falling through to the box would hand them compass
   * strings instead — type-checked and wrong.
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

    // A vetoed press starts no gesture, so no terminal callback arrives to
    // close it and the entry would otherwise describe a drag that never
    // happened.
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
    // Released in a `finally` so a throwing consumer cannot strand the gesture
    // and leave the reflow listeners attached, matching the guarantee
    // `dPointerDrag` makes for the gesture underneath.
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
   * Ends every gesture still held, on the way out.
   *
   * The engine reports nothing when the handles go, so a consumer that opened
   * something at the press would otherwise never get to close it, and destroying
   * this component would not release it either.
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
        // Swallowed only here: a destructor throws into the flush tearing down
        // every sibling component, and would take their cleanup with it.
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
      // Only `@handles` can pin `Payload` to something other than a compass
      // direction, and supplying it makes this branch unreachable — the getter
      // above prefers the descriptors. TypeScript cannot correlate the two.
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
      // The callback's own payload rather than the gesture's snapshot: with
      // positional keys, a descriptor list that changes mid-drag rebinds the
      // handler while the snapshot still holds what was pressed.
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
    // Detached as soon as nothing is left to re-measure, which is not the same
    // as no gesture being left: an unmeasured gesture can outlive a measured one.
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
    // Nothing to re-measure without `@measure`, which is the common case: the
    // built-in box reports no rect, so a document-wide capture-phase scroll
    // listener would run on every scroll to write null over null.
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
    {{! Keyed by index: the handles themselves hold no state, since a gesture is
      tracked here against its pointer, and a payload may repeat across handles.
      Positional keys are therefore both safe and collision-free. }}
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
