import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import effect from "discourse/float-kit/helpers/effect";
import concatClass from "discourse/helpers/concat-class";
import Outlet from "./outlet";

/**
 * Default opacity travel animation for backdrop.
 * @type {{ opacity: (params: { progress: number }) => number }}
 */
const DEFAULT_BACKDROP_TRAVEL_ANIMATION = {
  opacity: ({ progress }) => Math.min(progress * 0.33, 0.33),
};

/**
 * Backdrop component for d-sheet. Renders a semi-transparent overlay behind the sheet
 * content that can optionally respond to click/swipe interactions.
 *
 * @component Backdrop
 * @param {Object} sheet - The sheet controller instance
 * @param {boolean} [swipeable=true] - Whether backdrop responds to click/swipe
 * @param {Object|null} [travelAnimation] - Custom travel animation config. Properties can be:
 *   - [start, end] array for keyframe tweening
 *   - ({ progress, tween }) => value function
 *   - string for static values
 *   - null to disable
 *   Default: { opacity: ({ progress }) => Math.min(progress * 0.33, 0.33) }
 *   Set to { opacity: null } to disable default opacity animation.
 * @param {Object} [stackingAnimation] - Stacking animation config (same format as travelAnimation)
 */
export default class Backdrop extends Component {
  /**
   * The rendered backdrop DOM element.
   * @type {HTMLElement|null}
   */
  @tracked backdropElement = null;

  /**
   * Whether the backdrop responds to click/swipe interactions.
   * Defaults to true when the arg is not provided.
   *
   * @type {boolean}
   */
  get swipeable() {
    return this.args.swipeable ?? true;
  }

  /**
   * Effective travel animation config, merging default with provided config.
   * Converts array-style opacity values to interpolation functions.
   *
   * @type {Object|null}
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
   * Stores the rendered backdrop element.
   *
   * @param {HTMLElement} element
   */
  @action
  setBackdropElement(element) {
    this.backdropElement = element;
  }

  /**
   * Registers the backdrop with the sheet controller and returns a cleanup function.
   * Called via the effect helper when dependencies change.
   *
   * @param {Object} sheet - The sheet controller instance
   * @param {HTMLElement} backdropElement - The backdrop DOM element
   * @param {boolean} swipeable - Whether the backdrop responds to interactions
   * @param {Object|null} travelAnimation - The effective travel animation config
   * @returns {Function|undefined} Cleanup function to unregister the backdrop
   */
  @action
  syncBackdrop(sheet, backdropElement, swipeable, travelAnimation) {
    if (!sheet || !backdropElement) {
      return;
    }

    sheet.registerBackdrop(backdropElement, travelAnimation, swipeable);

    return () => {
      sheet.unregisterBackdrop(backdropElement);
    };
  }

  <template>
    {{#if @sheet}}
      {{effect
        this.syncBackdrop
        @sheet
        this.backdropElement
        this.swipeable
        this.effectiveTravelAnimation
      }}
      <Outlet
        @sheet={{@sheet}}
        @travelAnimation={{this.effectiveTravelAnimation}}
        @stackingAnimation={{@stackingAnimation}}
        data-d-sheet={{concatClass
          "backdrop"
          (if @sheet.scrollContainerShouldBePassThrough "no-pointer-events")
        }}
        {{didInsert this.setBackdropElement}}
        ...attributes
      />
    {{/if}}
  </template>
}
