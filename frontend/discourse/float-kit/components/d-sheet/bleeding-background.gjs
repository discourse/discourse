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
      @sheet.contentPlacementCssClass
      @sheet.tracks
      @sheet.stagingAttribute
    }}
    ...attributes
  ></div>
</template>;

export default BleedingBackground;
