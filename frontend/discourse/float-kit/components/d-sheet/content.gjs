import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import outletAnimationModifier from "./outlet-animation-modifier";
import scrollListenerModifier from "./scroll-listener-modifier";

/**
 * Renders the scrollable content area of a sheet including scroll containers, content wrapper, and detent markers.
 *
 * @component Content
 * @param {import("./controller").default} sheet - The sheet controller instance managing state, dimensions, and interactions
 * @param {Record<string, [number, number] | ((params: { progress: number, tween: Function }) => string) | string | null>} [travelAnimation] - Travel animation config. Properties can be:
 *   - [start, end] array for keyframe tweening
 *   - ({ progress, tween }) => value function
 *   - string for static values
 *   - null to disable
 *   Supports: opacity, visibility, transforms (translate, scale, rotate, skew variants),
 *   and any CSS property
 * @param {Record<string, [number, number] | ((params: { progress: number, tween: Function }) => string) | string | null>} [stackingAnimation] - Custom stacking animation config (same format as travelAnimation)
 * @param {boolean} [asChild] - When true, skips rendering the content div and yields attributes for child to apply
 */
export default class Content extends Component {
  /**
   * Generates inline CSS custom properties for positioning a detent marker relative to its neighbors.
   *
   * @param {Array<string>} detents - Array of CSS length values representing detent positions
   * @param {number} index - Zero-based index of the current detent in the array
   * @returns {import("@ember/template").SafeString} Inline style string with --d-sheet-marker-prev, --d-sheet-marker-current, and --d-sheet-marker-index custom properties
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
        @sheet.contentPlacementCssClass
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
          @sheet.contentPlacementCssClass
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
        {{#if @asChild}}
          {{yield
            (hash
              dataDSheet=(concatClass
                "content"
                @sheet.contentPlacementCssClass
                @sheet.tracks
                (if
                  @sheet.scrollContainerShouldBePassThrough "no-pointer-events"
                )
              )
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
