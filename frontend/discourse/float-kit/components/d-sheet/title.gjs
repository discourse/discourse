import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";

/**
 * Title component for sheets.
 *
 * @component DSheetTitle
 * @param {Object} sheet - The sheet controller instance
 */
export default class DSheetTitle extends Component {
  <template>
    <h2
      id={{@sheet.titleId}}
      class={{concatClass "Sheet-title" @class}}
      data-d-sheet="title"
      ...attributes
    >
      {{yield}}
    </h2>
  </template>
}
