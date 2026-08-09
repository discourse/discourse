import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import outletAnimationModifier from "./outlet-animation-modifier";
import registerSheetElement from "./register-sheet-element";

const DSheetTitle = <template>
  <h2
    id={{@sheet.titleId}}
    class="d-sheet__title"
    {{registerSheetElement @sheet.registerTitle @sheet.unregisterTitle}}
    {{outletAnimationModifier @sheet @travelAnimation @stackingAnimation}}
    ...attributes
    {{mergeSheetAttributes
      "outlet"
      "title"
      (if @sheet.isStackAnimating "animating")
    }}
  >
    {{yield}}
  </h2>
</template>;

export default DSheetTitle;
