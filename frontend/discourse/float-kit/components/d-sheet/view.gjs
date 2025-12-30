import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier as modifierFn } from "ember-modifier";
import effect from "discourse/float-kit/helpers/effect";
import concatClass from "discourse/helpers/concat-class";
import { eq, not, or } from "discourse/truth-helpers";
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
 * @param {string} contentPlacement - Placement: "top" | "bottom" | "left" | "right" | "center"
 * @param {string|Array<string>} tracks - Track content travels on: "top" | "bottom" | "left" | "right" | ["top", "bottom"] | ["left", "right"]
 * @param {Array<string>} detents - Detent values for the sheet
 * @param {boolean} swipe - Enable swipe gestures (default: true)
 * @param {boolean} swipeDismissal - Allow swipe to dismiss (default: true)
 * @param {boolean} swipeOvershoot - Allow overshoot (default: true)
 * @param {boolean|Object} swipeTrap - Trap swipes within the view
 * @param {boolean} nativeEdgeSwipePrevention - Prevent native edge swipe (default: false)
 * @param {Function} onSwipeFromEdgeToGoBackAttempt - Callback when edge swipe is attempted
 * @param {boolean} nativeFocusScrollPrevention - Prevent scroll on focus (default: true)
 * @param {boolean} pageScroll - Enable page-level scroll behavior
 * @param {boolean} inertOutside - Prevent interactions outside (default: true)
 * @param {Object} onClickOutside - Click outside behavior config
 * @param {Object|Function} onEscapeKeyDown - Escape key behavior config
 * @param {Object|Function} onPresentAutoFocus - Auto-focus on present config
 * @param {Object|Function} onDismissAutoFocus - Auto-focus on dismiss config
 * @param {string|Object} enteringAnimationSettings - Animation settings for opening
 * @param {string|Object} exitingAnimationSettings - Animation settings for closing
 * @param {string|Object} steppingAnimationSettings - Animation settings for stepping
 * @param {number|string} snapOutAcceleration - Snap out acceleration
 * @param {number|string} snapToEndDetentsAcceleration - Snap to end detents acceleration
 * @param {boolean|string} themeColorDimming - Whether to dim theme color
 * @param {number} themeColorDimmingAlpha - Alpha value for theme color dimming
 * @param {Function} onTravelStatusChange - Callback when travel status changes
 * @param {Function} onTravelRangeChange - Callback when travel range changes
 * @param {Function} onTravel - Callback during travel with progress
 * @param {Function} onTravelStart - Callback when travel starts
 * @param {Function} onTravelEnd - Callback when travel ends
 */
export default class View extends Component {
  /**
   * Modifier that registers the view element with the Controller.
   */
  registerView = modifierFn((element, [sheet]) => {
    sheet.registerView(element);
  });

  /**
   * Configure the Controller with behavioral options.
   * Called via effect helper when sheet or any configuration args change.
   *
   * @param {Object} sheet - The sheet controller instance
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
      nativeEdgeSwipePrevention: this.args.nativeEdgeSwipePrevention,
      onSwipeFromEdgeToGoBackAttempt: this.args.onSwipeFromEdgeToGoBackAttempt,
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

    if (this.args.inertOutside !== undefined) {
      sheet.updateScrollLock(this.args.inertOutside);
    }
  }

  <template>
    {{effect this.configureSheet @sheet}}

    <div
      data-d-sheet={{concatClass
        "view"
        @sheet.tracks
        (if (eq @sheet.currentState "closed") "closed")
        (if (not @sheet.inertOutside) "no-pointer-events")
        @sheet.effectiveSwipeTrapClass
        (concat "staging-" @sheet.animationState)
        (concat "openness-" @sheet.openness)
        "sheet-root"
        (if @sheet.isFocusable "focusable")
        (if (or @sheet.frontStuck @sheet.backStuck) "overshoot-active")
        "scroll-lock-participant"
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
          (if @sheet.isHorizontalTrack "scroll-horizontal" "scroll-vertical")
          @sheet.tracks
          (if (not @sheet.inertOutside) "no-pointer-events")
          (if @sheet.scrollContainerShouldBePassThrough "pass-through")
          (if
            @sheet.isScrollTrapActive
            "scroll-trap-active"
            "scroll-trap-inactive"
          )
          (if
            @sheet.isAutomaticallyDisabledForOptimisation
            "scroll-trap-optimised"
          )
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
    </div>
  </template>
}
