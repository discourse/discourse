import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import Outlet from "./outlet";

const BleedingBackground = <template>
  <Outlet
    @sheet={{@sheet}}
    @travelAnimation={{@travelAnimation}}
    @stackingAnimation={{@stackingAnimation}}
    {{didInsert (fn @sheet.setBleedingBackgroundPresent true)}}
    {{willDestroy (fn @sheet.setBleedingBackgroundPresent false)}}
    ...attributes
    {{mergeSheetAttributes
      "bleeding-background"
      @sheet.contentPlacementAttribute
      @sheet.tracks
      @sheet.stagingAttribute
      (if @sheet.isCenteredTrack "bleed-disabled")
    }}
  >
    {{yield}}
  </Outlet>
</template>;

export default BleedingBackground;
