import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import { eq, not } from "discourse/truth-helpers";
import { scrollTrapModifier } from "./scroll-trap-modifier";
import stackingAnimationModifier from "./stacking-animation-modifier";

/**
 * Content component for d-sheet - renders the scrollable content area with detent markers.
 *
 * @component Content
 * @param {Object} sheet - The sheet controller instance
 * @param {Object} stackingAnimation - Custom stacking animation config (optional)
 * @param {boolean} scrollTrapRoot - Whether content is a scroll trap root
 * @param {string} scrollTrapAxis - Axis for scroll trap ("horizontal" or "vertical")
 */
export default class Content extends Component {
  /**
   * Generates inline styles for a detent marker.
   *
   * @param {Array} detents - Array of detent values
   * @param {number} index - Index of the current detent
   * @returns {SafeString} Inline style string
   */
  stylesForDetentMarker(detents, index) {
    const currentDetent = detents[index];
    const prevDetent = index > 0 ? detents[index - 1] : "0px";

    return htmlSafe(
      `--d-sheet-marker-prev: ${prevDetent}; --d-sheet-marker-current: ${currentDetent}; --d-sheet-marker-index: ${index};`
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
        @sheet.contentPlacement
        (if @sheet.swipeOutDisabled "swipe-out-disabled")
        (if (not @sheet.swipeOvershoot) "overshoot-inactive")
        (if (not @sheet.inertOutside) "no-pointer-events")
      }}
      {{didInsert @sheet.registerScrollContainer}}
      {{on "scroll" @sheet.handleScrollForClose passive=true}}
      {{on "touchstart" @sheet.handleTouchStart passive=true}}
      {{on "touchend" @sheet.handleTouchEnd passive=true}}
    >
      <div data-d-sheet={{concatClass "front-spacer" @sheet.tracks}}></div>

      <div
        data-d-sheet={{concatClass
          "content-wrapper"
          @sheet.contentPlacement
          (if @sheet.swipeOvershoot "overshoot-active" "overshoot-inactive")
          (if @sheet.swipeOutDisabled "swipe-out-disabled")
          (if
            @sheet.isHorizontalTrack
            "snap-type-x-mandatory"
            "snap-type-y-mandatory"
          )
          @sheet.tracks
        }}
        {{didInsert @sheet.registerContentWrapper}}
      >
        <div
          data-d-sheet={{concatClass
            "content"
            @sheet.contentPlacement
            @sheet.tracks
            (if @scrollTrapRoot "scroll-trap-root")
            (if
              @scrollTrapRoot
              (if
                (eq @scrollTrapAxis "horizontal")
                "scroll-horizontal"
                "scroll-vertical"
              )
            )
            (if (not @sheet.inertOutside) "no-pointer-events")
          }}
          ...attributes
          {{didInsert @sheet.registerContent}}
          {{stackingAnimationModifier @sheet @stackingAnimation}}
          {{scrollTrapModifier @scrollTrapRoot}}
        >
          {{yield}}
        </div>
        {{#if @sheet.nativeEdgeSwipePrevention}}
          <div
            data-d-sheet={{concatClass "edge-marker" @sheet.tracks}}
            {{on "touchstart" @sheet.handleEdgeMarkerTouch passive=false}}
          ></div>
        {{/if}}
        <div
          data-d-sheet={{concatClass "touch-target-expander" @sheet.tracks}}
        ></div>
      </div>

      <div data-d-sheet={{concatClass "back-spacer" @sheet.tracks}}>
        {{#each @sheet.detents as |detent index|}}
          <div
            data-d-sheet={{concatClass
              "detent-marker"
              @sheet.tracks
              (if @sheet.swipeOutDisabled "swipe-out-disabled")
            }}
            style={{this.stylesForDetentMarker @sheet.detents index}}
            {{didInsert @sheet.registerDetentMarker}}
          ></div>
        {{/each}}
      </div>
    </div>
  </template>
}
