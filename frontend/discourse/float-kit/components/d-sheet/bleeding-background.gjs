import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";

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
