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

{{#if this.showSortingUI}}
  <DButton
    @action={{this.sortByLabel}}
    @icon={{this.sortIcon}}
    class="sort-btn"
  />
{{/if}}

{{#if this.label.htmlTitle}}
  <span class="title">{{html-safe this.label.htmlTitle}}</span>
{{else}}
  <span class="title">{{this.label.title}}</span>
{{/if}}