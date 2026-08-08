import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import outletAnimationModifier from "./outlet-animation-modifier";

const DSheetTitle = <template>
  <h2
    id={{@sheet.titleId}}
    class="d-sheet__title"
    {{didInsert @sheet.registerTitle}}
    {{willDestroy @sheet.unregisterTitle}}
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
