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

const RESTING_DETENT_STAGING_STATES = new Set([
  "go-down",
  "going-down",
  "going-up",
  "none",
]);

const preserveRestingDetent = modifier((element, [sheet, staging]) => {
  if (!RESTING_DETENT_STAGING_STATES.has(staging)) {
    return;
  }

  element.getBoundingClientRect();
  untrack(() => sheet.restoreRestingDetentAfterLayout());
});

const registerDetentMarker = modifier((element, [sheet, index]) => {
  sheet.registerDetentMarker(element, index);

  return () => sheet.unregisterDetentMarker(element, index);
});

const syncDetentMarkerStyles = modifier((element, [detents, index]) => {
  element.style.setProperty(
    "--d-sheet-marker-prev",
    index > 0 ? detents[index - 1] : "0px"
  );
  element.style.setProperty("--d-sheet-marker-current", detents[index]);
  element.style.setProperty("--d-sheet-marker-index", index);
});

export default class Content extends Component {
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
        "scroll-trap-marker"
        @sheet.tracks
        (concat "staging-" @sheet.state.staging.current)
        @sheet.effectiveSwipeTrapClass
        (if @sheet.swipeDisabled "swipe-disabled")
        (if @sheet.edgeAlignedNoOvershoot "overshoot-inactive")
        (if @sheet.scrollContainerShouldBePassThrough "no-pointer-events")
      }}
      {{registerSheetElement
        @sheet.registerScrollContainer
        @sheet.unregisterScrollContainer
      }}
      {{preserveRestingDetent @sheet @sheet.state.staging.current}}
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
          (if
            @sheet.edgeAlignedNoOvershoot
            "overshoot-inactive"
            "overshoot-active"
          )
          (if @sheet.swipeOutDisabledWithDetent "swipe-out-disabled")
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
        {{#each @sheet.detents key="@index" as |detent index|}}
          <div
            data-d-sheet={{concatClass
              "detent-marker"
              @sheet.tracks
              (if @sheet.swipeOutDisabledWithDetent "swipe-out-disabled")
            }}
            {{syncDetentMarkerStyles @sheet.detents index}}
            {{registerDetentMarker @sheet index}}
          ></div>
        {{/each}}
      </div>
    </div>
  </template>
}
