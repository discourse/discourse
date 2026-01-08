/**
 * Description component for sheets.
 *
 * @component DSheetDescription
 * @param {Object} sheet - The sheet controller instance
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
