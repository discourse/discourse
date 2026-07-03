// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import dFit from "discourse/ui-kit/modifiers/d-fit";

/**
 * Behavior-critical inline styles. They live inline (not in a stylesheet) so
 * the component measures and swaps correctly anywhere it renders, including
 * stylesheet-less rendering tests.
 *
 * Host: `position: relative` makes the host the containing block for the
 * hidden full pane; `align-self: stretch` is inert in block layout but restores
 * the container-determined width inside a flex-column parent that aligns items
 * to the start (otherwise the host would shrink to its content and the swap
 * could never detect a cramped container).
 */
const HOST_STYLE = trustHTML("position: relative; align-self: stretch;");

/**
 * Probe: `min-width: max-content` lets the full rendition stretch to fill the
 * host when there is room while refusing to shrink below its natural width —
 * so the probe's `offsetWidth` exceeds the host's width exactly when the full
 * rendition does not fit.
 */
const PROBE_STYLE = trustHTML("min-width: max-content;");

/**
 * Hidden full pane: out of flow and invisible, but still measurable
 * (`offsetWidth` is computed under `visibility: hidden`, unlike
 * `display: none`) and out of the accessibility tree and tab order. `inset: 0`
 * sizes the pane to the host and `overflow: hidden` clips the oversized probe
 * inside, so the invisible content never contributes scrollable overflow to a
 * scrolling ancestor (which would otherwise show a phantom horizontal
 * scrollbar).
 */
const HIDDEN_PANE_STYLE = trustHTML(
  "position: absolute; inset: 0; overflow: hidden; visibility: hidden;"
);

/**
 * @typedef {object} DFitSwapSignature
 * @property {HTMLDivElement} Element
 * @property {object} Args
 * @property {unknown} [Args.remeasureOn] - Forwarded to the fit modifier's re-measure trigger.
 * @property {boolean} [Args.active] - Whether to track at all; defaults to true.
 * @property {HTMLElement} [Args.observedEl] - Optional override for the observed element.
 * @property {(decision: "full" | "collapsed") => void} [Args.onFit] - Notified with each applied decision.
 * @property {object} Blocks
 * @property {[]} Blocks.full - The roomier rendition (the default).
 * @property {[]} Blocks.collapsed - The compact fallback.
 */

/**
 * Renders one of two named blocks depending on whether the first one fits the
 * available width: `<:full>` (the default, roomier rendition) or
 * `<:collapsed>` (the compact fallback). The measurement, the shared batched
 * fit pass, and the swap are all handled here — consumers only provide the two
 * renditions:
 *
 * ```gjs
 * <DFitSwap @remeasureOn={{this.items}}>
 *   <:full><MySegmentedControl @items={{this.items}} /></:full>
 *   <:collapsed><MyDropdown @items={{this.items}} /></:collapsed>
 * </DFitSwap>
 * ```
 *
 * The decision is width-driven: the full rendition collapses when its natural
 * (un-shrunk) width no longer fits the host, and returns when there is room
 * again. The host exposes the current state as `data-fit="full|collapsed"` for
 * styling hooks.
 *
 * Notes for consumers:
 *  - The full rendition stays mounted while collapsed (hidden, unfocusable,
 *    out of the accessibility tree) so it can keep being measured; the
 *    collapsed rendition only renders while active.
 *  - Pass `@remeasureOn` (any tracked-derived value or array) when content
 *    changes can alter the full rendition's natural width without resizing the
 *    host — same semantics as the underlying fit modifier.
 *  - The host takes its container's width. In a flex-ROW parent the main axis
 *    is content-sized, so give the host a definite basis there (for example
 *    `flex: 1`).
 *  - Padding belongs on the rendition content, never on the host: the
 *    available width is the host's `clientWidth`, which includes padding, so
 *    host padding would skew the fit comparison.
 *
 * Pitfalls (each fails silently — no error, just wrong behavior):
 *  - The `<:full>` rendition is only HIDDEN while collapsed, never torn down, so
 *    its side effects keep running: timers, subscriptions, autofocus, and media
 *    playback do not stop. Pause and resume them from `@onFit`, or keep anything
 *    that must stop when hidden outside this component. `@onFit` runs in the fit
 *    WRITE phase, so its handler must not synchronously resize the content (the
 *    same rule as the fit `compute`), or it re-triggers the fit pass.
 *  - Both renditions can be in the DOM at once (the full one stays present while
 *    collapsed), so a duplicate `id`, or the same form control repeated across
 *    `<:full>` and `<:collapsed>`, collides. Give the two renditions distinct
 *    ids/names, or render shared form state once outside the swap.
 *  - Omitting `@remeasureOn` when the content's natural width changes without a
 *    host resize: the swap never re-evaluates and stays on its last decision.
 *
 * Args:
 *  - `@remeasureOn` — forwarded to the fit modifier's re-measure trigger.
 *  - `@active` — whether to track at all; defaults to true.
 *  - `@observedEl` — optional override for the element whose width drives the
 *    decision, when the host's own container is not the right reference.
 *  - `@onFit` — `(decision) => …`, called with the resolved `"full"`/
 *    `"collapsed"` decision on the initial fit pass and on each subsequent
 *    change. It piggybacks on the coordinator's diffed writes, so a re-measure
 *    that yields the same decision does not call it again. Use it to pause or
 *    resume work in a rendition that keeps running while hidden (see Pitfalls).
 *
 * @extends {Component<DFitSwapSignature>}
 */
export default class DFitSwap extends Component {
  /**
   * The current fit decision. Starts as "full" — the initial coalesced fit
   * pass corrects it before paint, so a cramped container never flashes the
   * full rendition.
   *
   * @type {"full" | "collapsed"}
   */
  @tracked decision = "full";

  /**
   * Holds a reference to the probe element for {@link computeFit}. A ref
   * modifier (rather than a subtree query) stays correct when swaps nest.
   */
  registerProbe = modifier((/** @type {HTMLElement} */ element) => {
    this.#probeEl = element;
    return () => {
      if (this.#probeEl === element) {
        this.#probeEl = null;
      }
    };
  });

  /** @type {HTMLElement | null} The probe wrapping the full rendition. */
  #probeEl = null;

  /**
   * Whether the collapsed rendition is the active one.
   *
   * @returns {boolean}
   */
  get isCollapsed() {
    return this.decision === "collapsed";
  }

  /**
   * The full pane's inline style: hidden-but-measurable while collapsed,
   * unstyled while active.
   *
   * @returns {typeof HIDDEN_PANE_STYLE | null}
   */
  get fullPaneStyle() {
    return this.isCollapsed ? HIDDEN_PANE_STYLE : null;
  }

  /**
   * The fit decision, run in the coordinator's shared read phase (reads only).
   * The probe reports its natural width whenever the full rendition doesn't
   * fit (its `min-width: max-content` refuses to shrink), so a probe wider
   * than the host means "collapse". The +1 slack absorbs sub-pixel rounding at
   * the boundary so an exact fit doesn't flip back and forth.
   *
   * @param {number} availWidth - The host's available width.
   * @returns {"full" | "collapsed"}
   */
  @action
  computeFit(availWidth) {
    if (!this.#probeEl) {
      return this.decision;
    }
    return this.#probeEl.offsetWidth >= availWidth + 1 ? "collapsed" : "full";
  }

  /**
   * Applies a changed fit decision, swapping which rendition is active, then
   * forwards it to `@onFit` so a consumer can react (state is updated first so
   * the handler sees the new decision).
   *
   * @param {"full" | "collapsed"} decision
   */
  @action
  onDecision(decision) {
    this.decision = decision;
    this.args.onFit?.(decision);
  }

  <template>
    <div
      class="d-fit-swap"
      data-fit={{this.decision}}
      ...attributes
      style={{HOST_STYLE}}
      {{dFit
        this.computeFit
        onChange=this.onDecision
        remeasureOn=@remeasureOn
        active=@active
        observedEl=@observedEl
      }}
    >
      {{! The full rendition is always mounted so it stays measurable while
        collapsed; only its visibility swaps. }}
      <div class="d-fit-swap__pane --full" style={{this.fullPaneStyle}}>
        <div
          class="d-fit-swap__probe"
          style={{PROBE_STYLE}}
          {{this.registerProbe}}
        >
          {{yield to="full"}}
        </div>
      </div>
      {{#if this.isCollapsed}}
        <div class="d-fit-swap__pane --collapsed">
          {{yield to="collapsed"}}
        </div>
      {{/if}}
    </div>
  </template>
}
