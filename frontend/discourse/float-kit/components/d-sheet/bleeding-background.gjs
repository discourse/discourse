import concatClass from "discourse/helpers/concat-class";

/**
 * BleedingBackground component for d-sheet.
 *
 * @component BleedingBackground
 * @param {Object} sheet - The sheet controller instance
 */
const BleedingBackground = <template>
  <div
    data-d-sheet={{concatClass
      "bleeding-background"
      @sheet.contentPlacementCssClass
      @sheet.tracks
    }}
    ...attributes
  ></div>
</template>;

export default BleedingBackground;
