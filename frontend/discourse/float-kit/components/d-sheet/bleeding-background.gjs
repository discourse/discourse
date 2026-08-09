import { modifier } from "ember-modifier";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import Outlet from "./outlet";

const syncPresence = modifier((_element, [setPresence]) => {
  setPresence(true);

  return () => setPresence(false);
});

const BleedingBackground = <template>
  <Outlet
    @sheet={{@sheet}}
    @travelAnimation={{@travelAnimation}}
    @stackingAnimation={{@stackingAnimation}}
    {{syncPresence @sheet.setBleedingBackgroundPresent}}
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
