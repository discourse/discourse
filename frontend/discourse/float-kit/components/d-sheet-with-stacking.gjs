import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import DSheet from "./d-sheet";
import DSheetBackdrop from "./d-sheet/backdrop";
import DSheetContent from "./d-sheet/content";
import DSheetView from "./d-sheet/view";
import DSheetStack from "./d-sheet-stack";

// ================================================================================================
// Stack Root
// ================================================================================================

/**
 * SheetWithStackingStack.Root - Thin wrapper around DSheetStack.Root
 * @component DSheetWithStackingStackRoot
 */
const StackRoot = <template>
  <DSheetStack.Root as |stack|>
    {{yield (hash stackId=stack.stackId)}}
  </DSheetStack.Root>
</template>;

// ================================================================================================
// Root
// ================================================================================================

/**
 * SheetWithStacking.Root - Creates context and wraps DSheet.Root
 * Following Silk's pattern:
 * - Creates context with travelStatus, contentPlacement
 * - Uses media query for responsive placement (right >= 700px, bottom < 700px)
 * - Accepts explicit stackId for stack association
 *
 * @component DSheetWithStackingRoot
 * @param {string} stackId - Stack ID from DSheetWithStackingStack.Root
 */
class Root extends Component {
  @tracked travelStatus = "idleOutside";

  // Following Silk's pattern: use media query for responsive placement
  // See silk/react-examples/SheetWithStacking - large viewport (>= 700px) uses "right", small uses "bottom"
  largeViewport = new TrackedMediaQuery("(min-width: 700px)");

  willDestroy() {
    super.willDestroy(...arguments);
    this.largeViewport.teardown();
  }

  get tracks() {
    return this.largeViewport.matches ? "right" : "bottom";
  }

  @action
  setTravelStatus(status) {
    this.travelStatus = status;
  }

  <template>
    <DSheet.Root @forComponent={{@stackId}} as |root|>
      {{yield
        (hash
          sheet=root.sheet
          travelStatus=this.travelStatus
          contentPlacement=this.tracks
          openSheet=root.openSheet
          Trigger=root.Trigger
          Portal=root.Portal
          View=(component
            View
            sheet=root.sheet
            detents=@detents
            tracks=this.tracks
            nativeEdgeSwipePrevention=true
            onTravelStatusChange=this.setTravelStatus
            onTravelRangeChange=@onTravelRangeChange
            onTravel=@onTravel
          )
          Backdrop=(component Backdrop sheet=root.sheet)
          Content=(component Content sheet=root.sheet tracks=this.tracks)
          Handle=root.Handle
          Outlet=root.Outlet
          Title=root.Title
          Description=root.Description
        )
      }}
    </DSheet.Root>
  </template>
}

// ================================================================================================
// View
// ================================================================================================

/**
 * SheetWithStacking.View - Wraps DSheet.View with stacking-specific config
 * @component DSheetWithStackingView
 */
const View = <template>
  <DSheetView
    class={{concatClass
      "SheetWithStacking-view"
      (concat "tracks-" @tracks)
      @class
    }}
    @sheet={{@sheet}}
    @detents={{@detents}}
    @tracks={{@tracks}}
    @nativeEdgeSwipePrevention={{@nativeEdgeSwipePrevention}}
    @onTravelStatusChange={{@onTravelStatusChange}}
    @onTravelRangeChange={{@onTravelRangeChange}}
    @onTravel={{@onTravel}}
    ...attributes
  >
    {{yield
      (hash
        Backdrop=(component Backdrop sheet=@sheet)
        Content=(component Content sheet=@sheet tracks=@tracks)
      )
    }}
  </DSheetView>
</template>;

// ================================================================================================
// Backdrop
// ================================================================================================

/**
 * SheetWithStacking.Backdrop - Configured with travel animation
 * Following Silk: travelAnimation={{ opacity: [0, 0.2] }}
 * @component DSheetWithStackingBackdrop
 */
const Backdrop = <template>
  <DSheetBackdrop
    class={{concatClass "SheetWithStacking-backdrop" @class}}
    @sheet={{@sheet}}
    @travelAnimation={{hash opacity=(array 0 0.2)}}
    ...attributes
  />
</template>;

// ================================================================================================
// Content
// ================================================================================================

/**
 * SheetWithStacking.Content - Applies stacking animation based on placement
 * Following Silk's stackingAnimation:
 * - For "right": translateX, scale, transformOrigin "0 50%"
 * - For "bottom": translateY, scale, transformOrigin "50% 0"
 *
 * @component DSheetWithStackingContent
 */
class Content extends Component {
  /**
   * Get stacking animation config based on tracks
   */
  get stackingAnimation() {
    const { tracks, stackingAnimation: propsAnimation } = this.args;

    const baseAnimation =
      tracks === "right"
        ? {
            translateX: ({ progress }) =>
              progress <= 1
                ? progress * -10 + "px"
                : `calc(-12.5px + 2.5px * ${progress})`,
            scale: [1, 0.933],
            transformOrigin: "0 50%",
          }
        : {
            translateY: ({ progress }) =>
              progress <= 1
                ? progress * -10 + "px"
                : `calc(-12.5px + 2.5px * ${progress})`,
            scale: [1, 0.933],
            transformOrigin: "50% 0",
          };

    // Merge with any custom animation from props
    return { ...baseAnimation, ...propsAnimation };
  }

  <template>
    <DSheetContent
      class={{concatClass
        "SheetWithStacking-content"
        (concat "tracks-" @tracks)
        @class
      }}
      @sheet={{@sheet}}
      @stackingAnimation={{this.stackingAnimation}}
      ...attributes
    >
      <div class="SheetWithStacking-innerContent">
        {{yield}}
      </div>
    </DSheetContent>
  </template>
}

// ================================================================================================
// Exports
// ================================================================================================

// Export both as properties of the default export
// This avoids TypeScript issues with named exports from .gjs files
const exports = {
  DSheetWithStacking: {
    Root,
    View,
    Backdrop,
    Content,
  },
  DSheetWithStackingStack: {
    Root: StackRoot,
  },
};

export default exports;
