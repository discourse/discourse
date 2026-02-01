/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";
import discourseComputed from "discourse/lib/decorators";

@tagName("")
export default class AdminReportTableCell extends Component {
  options = null;

  @alias("label.type") type;
  @alias("label.mainProperty") property;
  @alias("computedLabel.formattedValue") formattedValue;
  @alias("computedLabel.value") value;

  @discourseComputed("label", "data", "options")
  computedLabel(label, data, options) {
    return label.compute(data, options || {});
  }

  <template>
    <td
      title={{this.value}}
      class={{concatClass "admin-report-table-cell" this.type this.property}}
      ...attributes
    >
      {{htmlSafe this.formattedValue}}
    </td>
  </template>
}
