import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import outletAnimationModifier from "./outlet-animation-modifier";
import registerSheetElement from "./register-sheet-element";

const DSheetDescription = <template>
  <p
    id={{@sheet.descriptionId}}
    class="d-sheet__description"
    {{registerSheetElement
      @sheet.registerDescription
      @sheet.unregisterDescription
    }}
    {{outletAnimationModifier @sheet @travelAnimation @stackingAnimation}}
    ...attributes
    {{mergeSheetAttributes
      "outlet"
      "description"
      (if @sheet.isStackAnimating "animating")
    }}
  >
    {{yield}}
  </p>
</template>;

export default DSheetDescription;
