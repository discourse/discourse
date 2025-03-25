import Component from "@ember/component";
import {
  attributeBindings,
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@tagName("th")
@classNames("admin-report-table-header")
@classNameBindings("label.mainProperty", "label.type", "isCurrentSort")
@attributeBindings("label.title:title")
export default class AdminReportTableHeader extends Component {
  @discourseComputed("currentSortLabel.sortProperty", "label.sortProperty")
  isCurrentSort(currentSortField, labelSortField) {
    return currentSortField === labelSortField;
  }

  @discourseComputed("currentSortDirection")
  sortIcon(currentSortDirection) {
    return currentSortDirection === 1 ? "caret-up" : "caret-down";
  }
}
