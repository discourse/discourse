/**
 * Renders the description region of a sheet, linked via ID for accessibility.
 *
 * @component DSheetDescription
 * @param {import("./controller").default} sheet - The sheet controller instance providing descriptionId
 */
const DSheetDescription = <template>
  <div
    id={{@sheet.descriptionId}}
    class="Sheet-description"
    data-d-sheet="description"
    ...attributes
  >
    {{yield}}
  </div>
</template>;

export default DSheetDescription;
