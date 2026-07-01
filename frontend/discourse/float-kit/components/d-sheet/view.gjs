import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier as modifierFn } from "ember-modifier";
import effect from "discourse/float-kit/helpers/effect";
import { capabilities } from "discourse/services/capabilities";
import { or } from "discourse/truth-helpers";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import Backdrop from "./backdrop";
import Content from "./content";
import { scrollTrapModifier } from "./scroll-trap-modifier";

export default class View extends Component {
  registerView = modifierFn((element, [sheet]) => {
    sheet.registerView(element);
  });

  get showBottomColorHint() {
    return (this.args.bottomColorHint ?? true) && capabilities.isWebKit;
  }

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
    {{effect
      this.configureSheet
      @sheet
      @contentPlacement
      @tracks
      @detents
      @swipe
      @swipeDismissal
      @swipeOvershoot
      @swipeTrap
      @nativeFocusScrollPrevention
      @pageScroll
      @inertOutside
      @onClickOutside
      @onEscapeKeyDown
      @onPresentAutoFocus
      @onDismissAutoFocus
      @enteringAnimationSettings
      @exitingAnimationSettings
      @steppingAnimationSettings
      @snapOutAcceleration
      @snapToEndDetentsAcceleration
      @themeColorDimming
      @themeColorDimmingAlpha
      @onTravelStatusChange
      @onTravelRangeChange
      @onTravel
      @onTravelStart
      @onTravelEnd
    }}

    <div
      id={{@sheet.id}}
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
      aria-labelledby={{@sheet.labelledById}}
      aria-describedby={{@sheet.describedById}}
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
