import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { modifier } from "ember-modifier";
import dResizeEdge from "discourse/ui-kit/modifiers/d-resize-edge";

/**
 * Which cursor is held while a gesture on each axis runs, mapped by
 * `app/assets/stylesheets/common/ui-kit/d-resize-separator.scss`.
 */
const CURSOR_CLASS = {
  vertical: "d-resizing-ns",
  horizontal: "d-resizing-ew",
};

/**
 * Watches the box being resized so the announced size keeps up with changes no
 * gesture caused. Re-runs when `target` changes, which is what lets a consumer
 * whose element does not exist at first render hand it over once it does.
 */
const observeResized = modifier((separator, [separatorComponent, target]) => {
  const element = typeof target === "function" ? target(separator) : target;
  if (!element) {
    return;
  }

  const observer = new ResizeObserver(() => separatorComponent.refresh());
  observer.observe(element);

  return () => observer.disconnect();
});

/**
 * Re-reads the size when the viewport changes. Separate from watching the box
 * because bounds are commonly derived from the viewport — the largest a box may
 * grow is usually what is left of the window — and a window change need not alter
 * the box's own size, so nothing else would notice it.
 */
const refreshOnViewportChange = modifier((_element, [separatorComponent]) => {
  const onViewportChange = () => separatorComponent.refresh();
  window.addEventListener("resize", onViewportChange);

  return () => window.removeEventListener("resize", onViewportChange);
});

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
 *
 * Args:
 *  - `@axis` — `"vertical"` to resize height, `"horizontal"` to resize width.
 *    Defaults to `"vertical"`.
 *  - `@side` — the edge of the resized box the handle sits on, naming the edge
 *    OPPOSITE the one that moves: a handle at the top of a bottom-docked box is
 *    `"end"`. Defaults to `"start"`.
 *  - `@value`, `@min`, `@max` — the current size and its bounds, each a number or a
 *    function returning one. Pass a function whenever the number is a live
 *    measurement rather than tracked state.
 *  - `@label` — what the separator is called, already translated.
 *  - `@onResizeStart` — the gesture began. A notification; the return is ignored.
 *  - `@onResize(size)` — fired throughout the gesture; preview here.
 *  - `@onResizeEnd(size)` — fired once at the end; commit here.
 *  - `@observe` — the box being resized, so the announced size keeps up with changes
 *    no gesture caused, such as a panel opening or a preview toggling. Viewport
 *    changes are picked up regardless and need no arg.
 *    Either the element, or a function receiving the separator's own element and
 *    returning it. Pass the element when it may not exist at first render, since a
 *    change to it re-attaches the observer; a function is resolved once, which suits
 *    a box already around the separator when it renders.
 *
 * Attributes pass through, so a consumer keeps its own class alongside this one —
 * Glimmer merges the two rather than replacing — and may add its own modifiers.
 *
 * Anything passed as content renders inside the handle, for the ones that draw
 * themselves with a real element rather than a pseudo-element.
 */
export default class DResizeSeparator extends Component {
  /** The size and bounds as last read, for assistive technology to announce. */
  @tracked _announced = null;

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
   *
   * @returns {number|undefined} The current size.
   */
  get valueNow() {
    return this.#announce("value", "now");
  }

  get valueMin() {
    return this.#announce("min", "min");
  }

  get valueMax() {
    return this.#announce("max", "max");
  }

  /**
   * Resolves one announced number, from the mirror or from the arg directly.
   *
   * A number given as a number is already reactive, so it is read straight through:
   * mirroring it would freeze what is announced until something else happened to
   * trigger a re-read. Only a function needs the mirror, because a measurement has
   * no tracked state for the template to notice changing.
   *
   * @param {string} argName - Which arg to resolve.
   * @param {string} mirrorKey - Its key in the mirror.
   * @returns {number|undefined} The number to announce.
   */
  #announce(argName, mirrorKey) {
    const arg = this.args[argName];
    if (typeof arg === "function") {
      return this._announced?.[mirrorKey] ?? undefined;
    }
    return arg ?? undefined;
  }

  /** Re-reads the size. Called on insert, after every report, and by the observer. */
  @action
  refresh() {
    this.#snapshot();
  }

  /**
   * Deliberately does NOT re-read the size.
   *
   * The modifier reports a move and then, on the last one, the commit — both in the
   * same stack. Dirtying tracked state that the template consumes in between opens
   * a runloop, and a consumer callback reached with one already open is invoked
   * directly rather than through the wrapper that routes exceptions to Ember's
   * error handler, so a consumer that throws on commit has its exception escape as
   * an unhandled error instead. Mid-gesture there is nothing worth announcing
   * anyway: the size is still moving, and the commit re-reads it.
   *
   * @param {number} size - The size the gesture is passing through.
   */
  @action
  onResize(size) {
    this.args.onResize?.(size);
  }

  @action
  onResizeEnd(size) {
    this.args.onResizeEnd?.(size);
    this.#snapshot();
  }

  /**
   * Reads the size and bounds as they stand. Taken after every report rather than
   * derived, because what matters here are measurements the template cannot observe.
   */
  #snapshot() {
    this._announced = {
      now: this.#read(this.args.value) ?? undefined,
      min: this.#read(this.args.min),
      max: this.#read(this.args.max),
    };
  }

  #read(arg) {
    return typeof arg === "function" ? arg() : arg;
  }

  <template>
    {{! Above the splat is a default a consumer may replace; below it is something
      this component guarantees. `tabindex` is deliberately open, because a roving
      composite legitimately makes its inactive items unreachable, and lowering it
      invalidates nothing else. `role` is not, because the value attributes below
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
