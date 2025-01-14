import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import {
  attributeBindings,
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@tagName("td")
@classNames("admin-report-table-cell")
@classNameBindings("type", "property")
@attributeBindings("value:title")
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
}
