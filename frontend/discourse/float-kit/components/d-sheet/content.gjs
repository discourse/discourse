import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import { not } from "discourse/truth-helpers";
import outletAnimationModifier from "./outlet-animation-modifier";
import scrollListenerModifier from "./scroll-listener-modifier";

/**
 * Content component for d-sheet - renders the scrollable content area with detent markers.
 *
 * @component Content
 * @param {Object} sheet - The sheet controller instance
 * @param {Object} [travelAnimation] - Travel animation config. Properties can be:
 *   - [start, end] array for keyframe tweening
 *   - ({ progress, tween }) => value function
 *   - string for static values
 *   - null to disable
 *   Supports: opacity, visibility, transforms (translate, scale, rotate, skew variants),
 *   and any CSS property
 * @param {Object} [stackingAnimation] - Custom stacking animation config (same format as travelAnimation)
 * @param {boolean} asChild - When true, skips rendering the content div and yields attributes for child to apply
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

  /**
   * Builds the data-d-sheet attribute string for the content element.
   * Used when asChild=true to pass attributes to child component.
   *
   * @returns {string}
   */
  get contentDataDSheet() {
    const parts = [
      "content",
      this.args.sheet?.contentPlacementCssClass,
      this.args.sheet?.tracks,
    ];

    if (this.args.sheet?.scrollContainerShouldBePassThrough) {
      parts.push("no-pointer-events");
    }

    if (this.args.bleedingBackgroundPresent) {
      parts.push("no-bleeding-background");
    }

    return parts.filter(Boolean).join(" ");
  }

  <template>
    <div
      data-d-sheet={{concatClass
        "scroll-container"
        "overscroll-contain"
        "scroll-trap-marker"
        "scroll-behavior-smooth"
        @sheet.tracks
        @sheet.contentPlacementCssClass
        (concat "staging-" @sheet.staging)
        (concat "position-" @sheet.stateHelper.position)
        @sheet.effectiveSwipeTrapClass
        (if
          @sheet.isAutomaticallyDisabledForOptimisation "scroll-trap-optimised"
        )
        (if @sheet.swipeOutDisabled "swipe-out-disabled")
        (if (not @sheet.swipeOvershoot) "overshoot-inactive")
        (if @sheet.scrollContainerShouldBePassThrough "no-pointer-events")
      }}
      {{didInsert @sheet.registerScrollContainer}}
      {{scrollListenerModifier
        @sheet.processScrollFrame
        @sheet.isScrollOngoing
      }}
      {{on "scroll" @sheet.handleScrollStateChange passive=true}}
      {{on "touchstart" @sheet.handleTouchStart passive=true}}
      {{on "touchend" @sheet.handleTouchEnd passive=true}}
    >
      <div data-d-sheet={{concatClass "front-spacer" @sheet.tracks}}></div>

      <div
        data-d-sheet={{concatClass
          "content-wrapper"
          @sheet.contentPlacementCssClass
          (concat "staging-" @sheet.staging)
          (concat "position-" @sheet.stateHelper.position)
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
        {{#if @asChild}}
          {{yield
            (hash
              dataDSheet=this.contentDataDSheet
              registerContent=@sheet.registerContent
              travelAnimation=@travelAnimation
              stackingAnimation=@stackingAnimation
            )
          }}
        {{else}}
          <div
            data-d-sheet={{concatClass
              "content"
              @sheet.contentPlacementCssClass
              @sheet.tracks
              (if @sheet.scrollContainerShouldBePassThrough "no-pointer-events")
              (if @bleedingBackgroundPresent "no-bleeding-background")
            }}
            {{didInsert @sheet.registerContent}}
            {{outletAnimationModifier
              @sheet
              @travelAnimation
              @stackingAnimation
            }}
            ...attributes
          >
            {{yield}}
          </div>
        {{/if}}
        {{#if @sheet.nativeEdgeSwipePrevention}}
          <div
            data-d-sheet={{concatClass "left-edge" @sheet.tracks}}
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
