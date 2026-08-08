import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import outletAnimationModifier from "./outlet-animation-modifier";

const Outlet = <template>
  <div
    {{outletAnimationModifier @sheet @travelAnimation @stackingAnimation}}
    ...attributes
    {{mergeSheetAttributes "outlet" (if @sheet.isStackAnimating "animating")}}
  >
    {{yield}}
  </div>
</template>;

export default Outlet;
