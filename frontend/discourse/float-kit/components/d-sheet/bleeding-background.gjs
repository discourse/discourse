import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import concatClass from "discourse/helpers/concat-class";

/**
 * Renders a bleeding background div for the d-sheet that extends behind the sheet content.
 *
 * @component BleedingBackground
 * @param {import("./controller").default} sheet - The sheet controller instance providing placement, tracks, and staging state
 */
const BleedingBackground = <template>
  <div
    data-d-sheet={{concatClass
      "bleeding-background"
      @sheet.contentPlacementAttribute
      @sheet.tracks
      @sheet.stagingAttribute
    }}
    {{didInsert (fn @sheet.setBleedingBackgroundPresent true)}}
    {{willDestroy (fn @sheet.setBleedingBackgroundPresent false)}}
    ...attributes
  ></div>
</template>;

export default BleedingBackground;
