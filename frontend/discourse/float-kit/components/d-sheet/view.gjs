import Component from "@glimmer/component";
import { untrack } from "@glimmer/validator";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { modifier as modifierFn } from "ember-modifier";
import { capabilities } from "discourse/services/capabilities";
import { or } from "discourse/truth-helpers";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import nativeFocusScrollPrevention from "../d-scroll/native-focus-scroll-prevention";
import Backdrop from "./backdrop";
import Content from "./content";
import registerSheetElement from "./register-sheet-element";
import { scrollTrapModifier } from "./scroll-trap-modifier";

export default class View extends Component {
  configureSheet = modifierFn((_element, [sheet, configuration]) => {
    untrack(() => sheet?.configure(configuration));
  });

  constructor(owner, args) {
    super(owner, args);

    untrack(() => this.args.sheet?.configure(this.configuration));
  }

  get configuration() {
    return {
      contentPlacement: this.args.contentPlacement,
      detents: this.args.detents,
      enteringAnimationSettings: this.args.enteringAnimationSettings,
      exitingAnimationSettings: this.args.exitingAnimationSettings,
      inertOutside:
        this.args.inertOutside === undefined
          ? this.args.sheet?.rootComponent?.args.inertOutside
          : this.args.inertOutside,
      nativeFocusScrollPrevention: this.args.nativeFocusScrollPrevention,
      onClickOutside: this.args.onClickOutside,
      onDismissAutoFocus: this.args.onDismissAutoFocus,
      onEscapeKeyDown: this.args.onEscapeKeyDown,
      onFocusInside: this.args.onFocusInside,
      onPresentAutoFocus: this.args.onPresentAutoFocus,
      onTravel: this.args.onTravel,
      onTravelEnd: this.args.onTravelEnd,
      onTravelRangeChange: this.args.onTravelRangeChange,
      onTravelStart: this.args.onTravelStart,
      onTravelStatusChange: this.args.onTravelStatusChange,
      pageScroll: this.args.pageScroll,
      snapOutAcceleration: this.args.snapOutAcceleration,
      snapToEndDetentsAcceleration: this.args.snapToEndDetentsAcceleration,
      steppingAnimationSettings: this.args.steppingAnimationSettings,
      swipe: this.args.swipe,
      swipeDismissal: this.args.swipeDismissal,
      swipeOvershoot: this.args.swipeOvershoot,
      swipeTrap: this.args.swipeTrap,
      tracks: this.args.tracks,
    };
  }

  get showBottomColorHint() {
    return (this.args.bottomColorHint ?? true) && capabilities.isWebKit;
  }

  get shouldRender() {
    return this.args.shouldRenderView ?? this.args.sheet?.isPresented ?? false;
  }

  <template>
    {{#if this.shouldRender}}
      <div
        id={{@sheet.id}}
        tabindex="-1"
        role={{@sheet.role}}
        aria-labelledby={{@sheet.labelledById}}
        aria-describedby={{@sheet.describedById}}
        {{this.configureSheet @sheet this.configuration}}
        {{nativeFocusScrollPrevention @sheet.nativeFocusScrollPrevention}}
        {{registerSheetElement @sheet.registerView @sheet.unregisterView}}
        {{on "focus" @sheet.handleFocus capture=true}}
        ...attributes
        {{mergeSheetAttributes
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
    {{/if}}
  </template>
}
