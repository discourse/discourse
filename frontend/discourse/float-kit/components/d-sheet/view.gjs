import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier as modifierFn } from "ember-modifier";
import effect from "discourse/float-kit/helpers/effect";
import concatClass from "discourse/helpers/concat-class";
import { capabilities } from "discourse/services/capabilities";
import { or } from "discourse/truth-helpers";
import Backdrop from "./backdrop";
import Content from "./content";
import { scrollTrapModifier } from "./scroll-trap-modifier";

/**
 * View component for d-sheet.
 *
 * Renders the sheet view and configures the Controller with behavioral/visual props.
 *
 * @component DSheetView
 * @param {Object} sheet - The sheet controller instance
 * @param {string} [contentPlacement] - Placement: "top" | "bottom" | "left" | "right" | "center"
 * @param {string|Array<string>} [tracks] - Track content travels on: "top" | "bottom" | "left" | "right" | ["top", "bottom"] | ["left", "right"]
 * @param {Array<string>} [detents] - Detent values for the sheet
 * @param {boolean} [swipe=true] - Enable swipe gestures
 * @param {boolean} [swipeDismissal=true] - Allow swipe to dismiss
 * @param {boolean} [swipeOvershoot=true] - Allow overshoot
 * @param {boolean|Object} [swipeTrap] - Trap swipes within the view
 * @param {boolean} [nativeFocusScrollPrevention=true] - Prevent scroll on focus
 * @param {boolean} [pageScroll] - Enable page-level scroll behavior
 * @param {boolean} [inertOutside=true] - Prevent interactions outside
 * @param {Object} [onClickOutside] - Click outside behavior config
 * @param {Object|Function} [onEscapeKeyDown] - Escape key behavior config
 * @param {Object|Function} [onPresentAutoFocus] - Auto-focus on present config
 * @param {Object|Function} [onDismissAutoFocus] - Auto-focus on dismiss config
 * @param {string|Object} [enteringAnimationSettings] - Animation settings for opening
 * @param {string|Object} [exitingAnimationSettings] - Animation settings for closing
 * @param {string|Object} [steppingAnimationSettings] - Animation settings for stepping
 * @param {number|string} [snapOutAcceleration] - Snap out acceleration
 * @param {number|string} [snapToEndDetentsAcceleration] - Snap to end detents acceleration
 * @param {boolean|string} [themeColorDimming] - Whether to dim theme color
 * @param {number} [themeColorDimmingAlpha] - Alpha value for theme color dimming
 * @param {Function} [onTravelStatusChange] - Callback when travel status changes
 * @param {Function} [onTravelRangeChange] - Callback when travel range changes
 * @param {Function} [onTravel] - Callback during travel with progress
 * @param {Function} [onTravelStart] - Callback when travel starts
 * @param {Function} [onTravelEnd] - Callback when travel ends
 */
export default class View extends Component {
  /**
   * Modifier that registers the view element with the Controller.
   *
   * @type {import("ember-modifier").FunctionBasedModifier<{ Element: HTMLElement; Args: { Positional: [Object] } }>}
   */
  registerView = modifierFn((element, [sheet]) => {
    sheet.registerView(element);
  });

  get showBottomColorHint() {
    return (this.args.bottomColorHint ?? true) && capabilities.isWebKit;
  }

  /**
   * Configure the Controller with behavioral options.
   * Called via effect helper when sheet or any configuration args change.
   *
   * @param {Object} sheet - The sheet controller instance
   * @action
   */
  @action
  configureSheet(sheet) {
    if (!sheet) {
      return;
    }

    sheet.configure({
      contentPlacement: this.args.contentPlacement,
      tracks: this.args.tracks,
      detents: this.args.detents,
      swipe: this.args.swipe,
      swipeDismissal: this.args.swipeDismissal,
      swipeOvershoot: this.args.swipeOvershoot,
      swipeTrap: this.args.swipeTrap,
      nativeFocusScrollPrevention: this.args.nativeFocusScrollPrevention,
      pageScroll: this.args.pageScroll,
      inertOutside: this.args.inertOutside,
      onClickOutside: this.args.onClickOutside,
      onEscapeKeyDown: this.args.onEscapeKeyDown,
      onPresentAutoFocus: this.args.onPresentAutoFocus,
      onDismissAutoFocus: this.args.onDismissAutoFocus,
      enteringAnimationSettings: this.args.enteringAnimationSettings,
      exitingAnimationSettings: this.args.exitingAnimationSettings,
      steppingAnimationSettings: this.args.steppingAnimationSettings,
      snapOutAcceleration: this.args.snapOutAcceleration,
      snapToEndDetentsAcceleration: this.args.snapToEndDetentsAcceleration,
      themeColorDimming: this.args.themeColorDimming,
      themeColorDimmingAlpha: this.args.themeColorDimmingAlpha,
      onTravelStatusChange: this.args.onTravelStatusChange,
      onTravelRangeChange: this.args.onTravelRangeChange,
      onTravel: this.args.onTravel,
      onTravelStart: this.args.onTravelStart,
      onTravelEnd: this.args.onTravelEnd,
    });
  }

  <template>
    {{effect this.configureSheet @sheet}}

    <div
      data-d-sheet={{concatClass
        "view"
        @sheet.tracks
        (if @sheet.state.openness.isClosed "closed")
        (unless @sheet.inertOutside "no-pointer-events")
        @sheet.effectiveSwipeTrapClass
        (concat "staging-" @sheet.state.staging.current)
        (if @sheet.isStackAnimating "animating")
        "sheet-root"
        (if
          (or @sheet.state.stuck.isFront @sheet.state.stuck.isBack)
          "overshoot-active"
        )
      }}
      tabindex="-1"
      role={{@sheet.role}}
      aria-labelledby={{@sheet.titleId}}
      aria-describedby={{@sheet.descriptionId}}
      {{this.registerView @sheet}}
      {{on "focus" @sheet.handleFocus capture=true}}
      ...attributes
    >
      <div
        data-d-sheet={{concatClass
          "primary-scroll-trap"
          "scroll-trap-root"
          @sheet.primaryScrollTrapAxisClass
          @sheet.tracks
          (unless @sheet.inertOutside "no-pointer-events")
          (if @sheet.scrollContainerShouldBePassThrough "pass-through")
          (if
            @sheet.isScrollTrapActive
            "scroll-trap-active"
            "scroll-trap-inactive"
          )
          "scroll-trap-optimised"
          "scroll-trap-marker"
          "scroll-trap-end"
        }}
        {{scrollTrapModifier @sheet.isScrollTrapActive}}
      >
        <div data-d-sheet="scroll-trap-stabilizer">
          {{yield
            (hash
              Backdrop=(component Backdrop sheet=@sheet)
              Content=(component
                Content sheet=@sheet inertOutside=@sheet.inertOutside
              )
            )
          }}
        </div>
      </div>
      <div
        data-d-sheet={{concatClass
          "scroll-trap-root"
          "secondary-scroll-trap"
          "no-pointer-events"
          "scroll-trap-active"
          "scroll-both"
          "scroll-trap-marker"
          "scroll-trap-end"
        }}
        {{scrollTrapModifier true}}
      ></div>
      {{#if this.showBottomColorHint}}
        <div data-d-sheet="bottom-color-fade"></div>
        <div data-d-sheet="bottom-color-border"></div>
      {{/if}}
    </div>
  </template>
}
