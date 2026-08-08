import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import outletAnimationModifier from "./outlet-animation-modifier";

const DSheetDescription = <template>
  <p
    id={{@sheet.descriptionId}}
    class="d-sheet__description"
    {{didInsert @sheet.registerDescription}}
    {{willDestroy @sheet.unregisterDescription}}
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
