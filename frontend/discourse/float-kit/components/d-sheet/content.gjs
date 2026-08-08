import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { untrack } from "@glimmer/validator";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { getOwner } from "@ember/owner";
import curryComponent from "ember-curry-component";
import { modifier } from "ember-modifier";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import ContentTag from "./content-tag";
import registerSheetElement from "./register-sheet-element";
import scrollListenerModifier from "./scroll-listener-modifier";

export default class Content extends Component {
  preserveRestingDetent = modifier((element, [sheet, staging]) => {
    if (!["go-down", "going-down", "going-up", "none"].includes(staging)) {
      return;
    }

    element.getBoundingClientRect();
    untrack(() => sheet.restoreRestingDetentAfterLayout());
  });
  registerDetentMarker = modifier((element, [sheet, index]) => {
    sheet.registerDetentMarker(element, index);

    return () => sheet.unregisterDetentMarker(element, index);
  });
  syncDetentMarkerStyles = modifier((element, [detents, index]) => {
    element.style.setProperty(
      "--d-sheet-marker-prev",
      index > 0 ? detents[index - 1] : "0px"
    );
    element.style.setProperty("--d-sheet-marker-current", detents[index]);
    element.style.setProperty("--d-sheet-marker-index", index);
  });

  @cached
  get contentTag() {
    const component = this;

    return curryComponent(
      ContentTag,
      {
        get sheet() {
          return component.args.sheet;
        },
        get travelAnimation() {
          return component.args.travelAnimation;
        },
        get stackingAnimation() {
          return component.args.stackingAnimation;
        },
      },
      getOwner(this)
    );
  }

  <template>
    <div
      data-d-sheet={{concatClass
        "scroll-container"
        "overscroll-contain"
        "scroll-trap-marker"
        "scroll-behavior-smooth"
        @sheet.tracks
        @sheet.contentPlacementAttribute
        (concat "staging-" @sheet.state.staging.current)
        @sheet.effectiveSwipeTrapClass
        "scroll-trap-optimised"
        (if @sheet.swipeDisabled "swipe-disabled")
        (if @sheet.swipeOutDisabledWithDetent "swipe-out-disabled")
        (unless @sheet.swipeOvershoot "overshoot-inactive")
        (if @sheet.scrollContainerShouldBePassThrough "no-pointer-events")
      }}
      {{registerSheetElement
        @sheet.registerScrollContainer
        @sheet.unregisterScrollContainer
      }}
      {{this.preserveRestingDetent @sheet @sheet.state.staging.current}}
      {{scrollListenerModifier
        @sheet.processScrollFrame
        @sheet.state.openness.isScrollOngoing
      }}
      {{on "scroll" @sheet.handleScrollStateChange passive=true}}
      {{on "touchstart" @sheet.handleTouchStart passive=true}}
      {{on "touchend" @sheet.handleTouchEnd passive=true}}
    >
      <div data-d-sheet={{concatClass "front-spacer" @sheet.tracks}}></div>

      <div
        data-d-sheet={{concatClass
          "content-wrapper"
          @sheet.contentPlacementAttribute
          (concat "staging-" @sheet.state.staging.current)
          (if @sheet.swipeOvershoot "overshoot-active" "overshoot-inactive")
          (if @sheet.swipeOutDisabledWithDetent "swipe-out-disabled")
          (if
            @sheet.isHorizontalTrack
            "snap-type-x-mandatory"
            "snap-type-y-mandatory"
          )
          @sheet.tracks
        }}
        {{registerSheetElement
          @sheet.registerContentWrapper
          @sheet.unregisterContentWrapper
        }}
      >
        {{yield this.contentTag}}
      </div>

      <div data-d-sheet={{concatClass "back-spacer" @sheet.tracks}}>
        {{#each @sheet.detents as |detent index|}}
          <div
            data-d-sheet={{concatClass
              "detent-marker"
              @sheet.tracks
              (if @sheet.swipeOutDisabledWithDetent "swipe-out-disabled")
            }}
            {{this.syncDetentMarkerStyles @sheet.detents index}}
            {{this.registerDetentMarker @sheet index}}
          ></div>
        {{/each}}
      </div>
    </div>
  </template>
}
