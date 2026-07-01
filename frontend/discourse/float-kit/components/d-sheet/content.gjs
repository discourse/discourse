import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { trustHTML } from "@ember/template";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import ContentTag from "./content-tag";
import scrollListenerModifier from "./scroll-listener-modifier";

export default class Content extends Component {
  stylesForDetentMarker(detents, index) {
    const currentDetent = detents[index];
    const prevDetent = index > 0 ? detents[index - 1] : "0px";

    return trustHTML(
      `--d-sheet-marker-prev: ${prevDetent}; --d-sheet-marker-current: ${currentDetent}; --d-sheet-marker-index: ${index};`
    );
  }

  get contentTag() {
    return curryComponent(
      ContentTag,
      {
        sheet: this.args.sheet,
        travelAnimation: this.args.travelAnimation,
        stackingAnimation: this.args.stackingAnimation,
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
      {{didInsert @sheet.registerScrollContainer}}
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
        {{didInsert @sheet.registerContentWrapper}}
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
            style={{this.stylesForDetentMarker @sheet.detents index}}
            {{didInsert @sheet.registerDetentMarker}}
          ></div>
        {{/each}}
      </div>
    </div>
  </template>
}
