import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { modifier } from "ember-modifier";
import dResizeEdge, {
  type ResizeReportMeta,
} from "discourse/ui-kit/modifiers/d-resize-edge";

/**
 * A size, or a function returning one for a value the template cannot observe.
 * `null` is the unmeasured state — the component withholds `aria-valuenow`
 * until a size is known, so a measurement function may honestly say "not yet".
 */
type Measurement = number | null | (() => number | null);

/**
 * A bound, which unlike a size is never unmeasured: there is nothing to clamp
 * against until it is known, so an unmeasured bound would silently become `0`
 * in the gesture's arithmetic rather than mean "no limit".
 *
 * Documentation rather than enforcement. `strictNullChecks` is off repo-wide, so
 * `number | null` collapses to `number` and a nullable measurement still
 * type-checks here. What actually refuses one is the gesture's own guard.
 */
type Bound = number | (() => number);

/**
 * The box being resized: the element itself, or a function receiving the
 * separator's own element and returning it.
 */
type ObserveTarget =
  | Element
  | ((separator: HTMLElement) => Element | null | undefined);

/**
 * Which cursor is held while a gesture on each axis runs, mapped by
 * `app/assets/stylesheets/common/ui-kit/d-resize-separator.scss`.
 */
const CURSOR_CLASS = {
  vertical: "d-resizing-ns",
  horizontal: "d-resizing-ew",
};

interface ObserveResizedSignature {
  Element: HTMLElement;
  Args: {
    Positional: [separator: DResizeSeparator, target?: ObserveTarget];
  };
}

/**
 * Watches the box being resized so the announced size keeps up with changes no
 * gesture caused.
 *
 * Re-runs when `target` changes, which is what lets a consumer pass the element
 * itself once it exists. A function `target` is resolved on each run, so a stable
 * function reference is never retried — that form suits a box already around the
 * separator when it renders.
 */
const observeResized = modifier<ObserveResizedSignature>(
  (separator, [separatorComponent, target]) => {
    const element = typeof target === "function" ? target(separator) : target;
    if (!element) {
      return;
    }

    const observer = new ResizeObserver(() => separatorComponent.refresh());
    observer.observe(element);

    return () => observer.disconnect();
  }
);

interface RefreshOnViewportChangeSignature {
  Element: HTMLElement;
  Args: {
    Positional: [separator: DResizeSeparator];
  };
}

/**
 * Re-reads the size when the viewport changes. Separate from watching the box
 * because bounds are commonly derived from the viewport — the largest a box may
 * grow is usually what is left of the window — and a window change need not alter
 * the box's own size, so nothing else would notice it.
 */
const refreshOnViewportChange = modifier<RefreshOnViewportChangeSignature>(
  (_element, [separatorComponent]) => {
    const onViewportChange = () => separatorComponent.refresh();
    window.addEventListener("resize", onViewportChange);

    return () => window.removeEventListener("resize", onViewportChange);
  }
);

interface DResizeSeparatorSignature {
  /** The separator itself. Attributes and modifiers pass through to it. */
  Element: HTMLDivElement;
  Args: {
    /**
     * `"vertical"` to resize height, `"horizontal"` to resize width. Defaults to
     * `"vertical"`.
     */
    axis?: "vertical" | "horizontal";

    /**
     * The edge of the resized box the handle sits on, naming the edge OPPOSITE
     * the one that moves: a handle at the top of a bottom-docked box is `"end"`.
     * Defaults to `"start"`.
     */
    side?: "start" | "end";

    /**
     * The current size. Pass a function whenever the number is a live
     * measurement rather than tracked state.
     */
    value: Measurement;

    /** The smallest size the box may be dragged to. */
    min: Bound;

    /** The largest size the box may be dragged to. */
    max: Bound;

    /**
     * What the separator is called, already translated. Required: a focusable
     * `role="separator"` with no accessible name is announced as a bare
     * "splitter", which says nothing about what it resizes.
     */
    label: string;

    /** The gesture began. A notification; the return is ignored. */
    onResizeStart?: () => void;

    /** Fired throughout the gesture. Preview here. */
    onResize?: (size: number) => void;

    /** Fired once at the end. Commit here. */
    onResizeEnd?: (size: number) => void;

    /**
     * The box being resized, so the announced size keeps up with changes no
     * gesture caused, such as a panel opening or a preview toggling. Viewport
     * changes are picked up regardless and need no arg.
     *
     * Either the element, or a function receiving the separator's own element and
     * returning it. Pass the element when it may not exist at first render, since
     * a change to it re-attaches the observer; a function is resolved once, which
     * suits a box already around the separator when it renders.
     */
    observe?: ObserveTarget;
  };
  Blocks: {
    /**
     * Rendered inside the handle, for the ones that draw themselves with a real
     * element rather than a pseudo-element.
     */
    default: [];
  };
}

/**
 * A one-axis resize handle that is operable and announced: the separator semantics
 * and the gesture bound together, so a consumer supplies only the size and what to
 * do with it.
 *
 * Wraps {@link dResizeEdge}, which keeps the value math, the bounds, the keyboard
 * path and the writing-direction flip. What this adds is everything a consumer
 * would otherwise hand-write beside that modifier, and can get subtly wrong:
 *
 *  - The separator contract — `role`, one tab stop, and an `aria-orientation` that
 *    is the OPPOSITE of the axis, because a separator between vertically stacked
 *    regions is itself a horizontal bar.
 *  - A tracked mirror of the size for `aria-valuenow`/`min`/`max`. These cannot
 *    reuse the modifier's args as they stand: a live measurement has to reach the
 *    modifier as a function or it would be read once and every later gesture would
 *    work from a stale value, while assistive technology needs a value the template
 *    can re-render from.
 *  - Withholding `aria-valuenow` until a size is known. Reporting `0` would claim
 *    the box has no extent; an absent value says "not measured yet".
 *  - Holding the cursor for the length of the gesture. Whether the cursor of the
 *    element a drag began on survives the pointer leaving it is engine-dependent,
 *    so the intent is stated on the page instead of left to the handle.
 *
 * Sizes carry no unit of their own: they are whatever `@value`, `@min` and `@max`
 * are expressed in, which is a height for a stacked splitter and a width for a
 * side panel.
 *
 * @example
 * ```gjs
 * <DResizeSeparator
 *   @axis="vertical"
 *   @side="end"
 *   @value={{this.height}}
 *   @min={{this.minHeight}}
 *   @max={{this.maxHeight}}
 *   @label={{i18n "composer.resize"}}
 *   @onResize={{this.preview}}
 *   @onResizeEnd={{this.commit}}
 *   class="my-block__handle"
 * />
 * ```
 *
 * Attributes pass through, so a consumer keeps its own class alongside this one —
 * the two are merged rather than replaced — and may add its own modifiers.
 *
 * @see {@link dResizeEdge}, the modifier underneath. Use it directly only when the
 *   element and its separator semantics are already yours to own.
 * @see The `DResizeHandles` component for a TWO-dimensional box resize, where the separator role
 *   does not apply.
 * @see The `dOnResize` modifier to merely OBSERVE a size change. It is not a gesture.
 */
export default class DResizeSeparator extends Component<DResizeSeparatorSignature> {
  /** The size and bounds as last read, for assistive technology to announce. */
  @tracked
  _announced: {
    now: number | undefined;
    min: number | undefined;
    max: number | undefined;
  } | null = null;

  get axis() {
    return this.args.axis ?? "vertical";
  }

  /** A separator's orientation is its own direction, not the axis it moves. */
  get orientation() {
    return this.axis === "horizontal" ? "vertical" : "horizontal";
  }

  get cursorClass() {
    return CURSOR_CLASS[this.axis];
  }

  /**
   * The size to announce, or `undefined` while it is unknown so that the attribute
   * is left off rather than reporting a number nothing measured.
   */
  get valueNow() {
    const now = this.#announce("value", "now");
    if (now === undefined) {
      return undefined;
    }

    // ARIA requires the announced size to lie within the announced bounds, and a
    // bound derived from the viewport can drop below a size the consumer has not
    // reduced yet. Clamped in the same order as the gesture's own clamp, so the
    // two agree about which bound wins when they conflict.
    const min = this.valueMin;
    const max = this.valueMax;
    return Math.max(Math.min(now, max ?? now), min ?? now);
  }

  get valueMin() {
    return this.#announce("min", "min");
  }

  get valueMax() {
    return this.#announce("max", "max");
  }

  /** Re-reads the size. Called on insert, after every report, and by the observer. */
  @action
  refresh() {
    this.#snapshot();
  }

  /**
   * Re-reads the size only for a keyboard gesture.
   *
   * The modifier reports a move and then, on the last one, the commit — both in the
   * same stack. Dirtying tracked state that the template consumes in between opens
   * a runloop, and a consumer callback reached with one already open is invoked
   * directly rather than through the wrapper that routes exceptions to the
   * application error handler, so a consumer that throws on commit has its exception escape as
   * an unhandled error instead. Mid-gesture there is nothing worth announcing
   * anyway: the size is still moving, and the commit re-reads it.
   *
   * @param size - The size the gesture is passing through.
   * @param meta - What produced the report. A held key is one gesture spanning
   *   every repeat, so it is the only source whose announcement cannot wait for
   *   the commit.
   */
  @action
  onResize(size: number, meta: ResizeReportMeta) {
    this.args.onResize?.(size);

    // A held arrow key is one gesture spanning every repeat, so the commit that
    // normally refreshes this does not arrive until release. Without the
    // snapshot here the announced value would be stale for the whole hold,
    // which is exactly the path this component exists to provide. The runloop
    // concern above does not apply: a key report is not inside a frame/commit
    // stack with a consumer callback after it.
    if (meta.source === "keyboard") {
      this.#snapshot(size);
    }
  }

  @action
  onResizeEnd(size: number) {
    this.args.onResizeEnd?.(size);
    this.#snapshot(size);
  }

  /**
   * Resolves one announced number, from the mirror or from the arg directly.
   *
   * A number given as a number is already reactive, so it is read straight through:
   * mirroring it would freeze what is announced until something else happened to
   * trigger a re-read. Only a function needs the mirror, because a measurement has
   * no tracked state for the template to notice changing.
   *
   * @param argName - Which arg to resolve.
   * @param mirrorKey - Its key in the mirror.
   */
  #announce(
    argName: "value" | "min" | "max",
    mirrorKey: "now" | "min" | "max"
  ): number | undefined {
    const arg = this.args[argName];
    if (typeof arg === "function") {
      return this._announced?.[mirrorKey] ?? undefined;
    }
    return arg ?? undefined;
  }

  /**
   * Reads the size and bounds as they stand. Taken after every report rather than
   * derived, because what matters here are measurements the template cannot observe.
   */
  #snapshot(reportedSize?: number) {
    // The reported size wins over re-reading the arg. A consumer whose `value`
    // measures the DOM applies the new size through tracked state, which has not
    // rendered yet while this runs inside its callback, so re-reading would
    // announce the size the box is moving away from.
    const now = reportedSize ?? this.#read(this.args.value) ?? undefined;
    const min = this.#read(this.args.min);
    const max = this.#read(this.args.max);
    const announced = this._announced;

    // Assigning invalidates whether or not the numbers differ, so a refresh that
    // read the same three would re-render the announced values for no change.
    // That is the common case rather than the rare one: the box observer and the
    // viewport listener both refresh during a window resize, landing two
    // refreshes in one frame, and a viewport change need not resize the box at
    // all.
    if (
      announced &&
      announced.now === now &&
      announced.min === min &&
      announced.max === max
    ) {
      return;
    }

    this._announced = { now, min, max };
  }

  #read(arg: Measurement): number | null {
    return typeof arg === "function" ? arg() : arg;
  }

  <template>
    {{! Above the splat is a default a consumer may replace; below it is something
      this component guarantees. The tabindex is deliberately open, because a roving
      composite legitimately makes its inactive items unreachable, and lowering it
      invalidates nothing else. The role is not, because the value attributes below
      are only meaningful on a separator, so overriding it would leave the element
      carrying attributes its role does not allow. }}
    <div
      class="d-resize-separator"
      tabindex="0"
      ...attributes
      role="separator"
      data-resize-axis={{this.axis}}
      aria-orientation={{this.orientation}}
      aria-label={{@label}}
      aria-valuenow={{this.valueNow}}
      aria-valuemin={{this.valueMin}}
      aria-valuemax={{this.valueMax}}
      {{didInsert this.refresh}}
      {{observeResized this @observe}}
      {{refreshOnViewportChange this}}
      {{dResizeEdge
        value=@value
        min=@min
        max=@max
        axis=this.axis
        side=@side
        bodyClass=this.cursorClass
        onResizeStart=@onResizeStart
        onResize=this.onResize
        onResizeEnd=this.onResizeEnd
      }}
    >{{yield}}</div>
  </template>
}
