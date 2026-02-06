import concatClass from "discourse/helpers/concat-class";

/**
 * Renders the title heading of a sheet, linked via ID for accessibility.
 *
 * @component DSheetTitle
 * @param {import("./controller").default} sheet - The sheet controller instance providing titleId
 * @param {string} [class] - Optional CSS class appended to the title element
 */
const DSheetTitle = <template>
  <h2
    id={{@sheet.titleId}}
    class={{concatClass "Sheet-title" @class}}
    data-d-sheet="title"
    ...attributes
  >
    {{yield}}
  </h2>
</template>;

export default DSheetTitle;
