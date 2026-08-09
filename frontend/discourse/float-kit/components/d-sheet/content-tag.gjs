import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import outletAnimationModifier from "./outlet-animation-modifier";
import registerSheetElement from "./register-sheet-element";

const ContentTag = <template>
  <div
    ...attributes
    {{mergeSheetAttributes
      "content"
      @sheet.contentPlacementAttribute
      @sheet.tracks
      (if @sheet.scrollContainerShouldBePassThrough "no-pointer-events")
      (if @sheet.bleedingBackgroundPresent "bleeding-background-present")
    }}
    {{registerSheetElement @sheet.registerContent @sheet.unregisterContent}}
    {{outletAnimationModifier @sheet @travelAnimation @stackingAnimation}}
  >
    {{yield}}
  </div>
</template>;

export default ContentTag;
