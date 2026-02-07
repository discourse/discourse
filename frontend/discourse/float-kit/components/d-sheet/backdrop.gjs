import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import effect from "discourse/float-kit/helpers/effect";
import concatClass from "discourse/helpers/concat-class";
import { capabilities } from "discourse/services/capabilities";
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
   * Override for the travel animation when theme color dimming takes over opacity.
   * @type {Object|null}
   */
  @tracked _travelAnimationOverride = null;

  _themeColorDimmingAlpha = 0;
  _themeColorDimmingOverlay = null;
  _themeColorDimmingTravelCleanup = null;

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
   * Whether theme color dimming is effectively enabled.
   * When set to "auto", checks WebKit capabilities.
   *
   * @type {boolean}
   */
  get effectiveThemeColorDimming() {
    const dimming = this.args.themeColorDimming ?? false;
    if (dimming === "auto") {
      return (
        capabilities.isWebKit && !capabilities.isStandaloneWithBlackTranslucent
      );
    }
    return Boolean(dimming);
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
   * Returns the override animation when dimming is active, otherwise the effective animation.
   *
   * @type {Object|null}
   */
  get activeTravelAnimation() {
    return this._travelAnimationOverride ?? this.effectiveTravelAnimation;
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
   * @param {Object|null} travelAnimation - Tracked dependency for re-registration
   * @returns {Function|undefined} Cleanup function to unregister the backdrop
   */
  @action
  syncBackdrop(sheet, backdropElement, swipeable, travelAnimation) {
    // travelAnimation is a tracked dependency that triggers re-registration
    // when the animation override changes, but is not passed to the controller
    void travelAnimation;

    if (!sheet || !backdropElement) {
      return;
    }

    sheet.registerBackdrop(backdropElement, swipeable);

    return () => {
      sheet.unregisterBackdrop(backdropElement);
    };
  }

  /**
   * Manages theme color dimming lifecycle, gated by long-running state.
   * When active, registers an overlay and a travel animation that drives
   * both backdrop opacity and the overlay alpha.
   *
   * @param {Object} sheet - The sheet controller instance
   * @param {HTMLElement} backdropElement - The backdrop DOM element
   * @param {boolean} effectiveThemeColorDimming - Whether dimming is enabled
   * @param {boolean} longRunningActive - Whether long-running state is active
   * @returns {Function|undefined} Cleanup function
   */
  @action
  syncThemeColorDimming(
    sheet,
    backdropElement,
    effectiveThemeColorDimming,
    longRunningActive
  ) {
    if (
      !sheet ||
      !backdropElement ||
      !effectiveThemeColorDimming ||
      !longRunningActive
    ) {
      return;
    }

    const animation = this.effectiveTravelAnimation;
    const opacityFn =
      typeof animation?.opacity === "function"
        ? animation.opacity
        : ({ progress }) => Math.min(progress * 0.33, 0.33);

    this._travelAnimationOverride = animation
      ? { ...animation, opacity: "ignore" }
      : { opacity: "ignore" };

    const computedStyle = window.getComputedStyle(backdropElement);
    const backgroundColor = computedStyle.backgroundColor || "rgb(0, 0, 0)";

    this._themeColorDimmingOverlay =
      sheet.themeColorAdapter.registerThemeColorDimmingOverlay({
        color: backgroundColor,
        alpha: this._themeColorDimmingAlpha,
      });

    this._themeColorDimmingTravelCleanup = sheet.registerTravelAnimation({
      callback: (progress) => {
        const opacity = opacityFn({ progress });
        this._themeColorDimmingAlpha = opacity;
        backdropElement.style.setProperty("opacity", opacity);

        if (this._themeColorDimmingOverlay) {
          this._themeColorDimmingOverlay.updateAlpha(opacity);
        }
      },
    });

    return () => {
      this._themeColorDimmingTravelCleanup?.();
      this._themeColorDimmingTravelCleanup = null;

      this._themeColorDimmingOverlay?.remove?.();
      this._themeColorDimmingOverlay = null;

      this._themeColorDimmingAlpha = 0;
      this._travelAnimationOverride = null;
    };
  }

  <template>
    {{#if @sheet}}
      {{effect
        this.syncBackdrop
        @sheet
        this.backdropElement
        this.swipeable
        this.activeTravelAnimation
      }}
      {{effect
        this.syncThemeColorDimming
        @sheet
        this.backdropElement
        this.effectiveThemeColorDimming
        @sheet.state.longRunning.isActive
      }}
      <Outlet
        @sheet={{@sheet}}
        @travelAnimation={{this.activeTravelAnimation}}
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
