import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";
import Outlet from "./outlet";

/**
 * Default opacity travel animation for backdrop.
 * @type {Object}
 */
const DEFAULT_BACKDROP_TRAVEL_ANIMATION = {
  opacity: ({ progress }) => Math.min(progress * 0.33, 0.33),
};

/**
 * Backdrop component for d-sheet. Renders a semi-transparent overlay behind the sheet
 * content that can optionally respond to click/swipe interactions.
 *
 * @component Backdrop
 * @param @sheet {Object} The sheet controller instance
 * @param @swipeable {boolean} Whether backdrop responds to click/swipe (default: true)
 * @param @travelAnimation {Object} Custom travel animation config. Properties can be:
 *   - [start, end] array for keyframe tweening
 *   - ({ progress, tween }) => value function
 *   - string for static values
 *   - null to disable
 *   Default: { opacity: ({ progress }) => Math.min(progress * 0.33, 0.33) }
 *   Set to { opacity: null } to disable default opacity animation.
 * @param @stackingAnimation {Object} Stacking animation config (same format as travelAnimation)
 */
export default class Backdrop extends Component {
  /**
   * Whether the backdrop responds to click/swipe interactions.
   *
   * @returns {boolean}
   */
  get swipeable() {
    return this.args.swipeable ?? true;
  }

  /**
   * Effective travel animation config, merging default with provided config.
   *
   * @returns {Object|null}
   */
  get effectiveTravelAnimation() {
    const userAnimation = this.args.travelAnimation;

    if (userAnimation === null) {
      return null;
    }

    const merged = { ...DEFAULT_BACKDROP_TRAVEL_ANIMATION, ...userAnimation };

    if (Array.isArray(merged.opacity)) {
      const [start, end] = merged.opacity;
      merged.opacity = ({ progress }) => start + (end - start) * progress;
    }

    return merged;
  }

  /**
   * Registers the backdrop element with the sheet controller.
   *
   * @param {HTMLElement} element
   */
  @action
  registerBackdropElement(element) {
    this.args.sheet.registerBackdrop(
      element,
      this.effectiveTravelAnimation,
      this.swipeable
    );
  }

  <template>
    {{#if @sheet}}
      <Outlet
        @sheet={{@sheet}}
        @travelAnimation={{this.effectiveTravelAnimation}}
        @stackingAnimation={{@stackingAnimation}}
        data-d-sheet={{concatClass
          "backdrop"
          (unless this.swipeable "no-pointer-events")
        }}
        {{didInsert this.registerBackdropElement}}
        ...attributes
      />
    {{/if}}
  </template>
}
