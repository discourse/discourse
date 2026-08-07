import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
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
 *  - `@onRegisterApi({ refresh })` — receives a handle whose `refresh()` re-reads
 *    the size. Needed only where the box can change size without the separator
 *    being touched, since nothing else can know that happened.
 *
 * Attributes pass through, so a consumer keeps its own class and may add modifiers.
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
    return this._announced?.now ?? undefined;
  }

  get valueMin() {
    return this._announced?.min ?? undefined;
  }

  get valueMax() {
    return this._announced?.max ?? undefined;
  }

  @action
  captureSize() {
    this.#snapshot();
    this.args.onRegisterApi?.({ refresh: this.refresh });
  }

  @action
  refresh() {
    this.#snapshot();
  }

  @action
  onResize(size) {
    this.args.onResize?.(size);
    this.#snapshot();
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
    <div
      data-resize-separator
      data-resize-axis={{this.axis}}
      role="separator"
      aria-orientation={{this.orientation}}
      aria-label={{@label}}
      aria-valuenow={{this.valueNow}}
      aria-valuemin={{this.valueMin}}
      aria-valuemax={{this.valueMax}}
      tabindex="0"
      {{didInsert this.captureSize}}
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
      ...attributes
    ></div>
  </template>
}
