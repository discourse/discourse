import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import outletAnimationModifier from "./outlet-animation-modifier";

const ContentTag = <template>
  <div
    ...attributes
    {{mergeSheetAttributes
      "content"
      @sheet.contentPlacementAttribute
      @sheet.tracks
      (if @sheet.scrollContainerShouldBePassThrough "no-pointer-events")
    }}
    {{didInsert @sheet.registerContent}}
    {{outletAnimationModifier @sheet @travelAnimation @stackingAnimation}}
  >
    {{yield}}
  </div>
</template>;

export default ContentTag;
