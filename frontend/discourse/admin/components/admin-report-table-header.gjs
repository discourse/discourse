/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import DButton from "discourse/components/d-button";

@tagName("th")
@classNames("admin-report-table-header")
@classNameBindings("label.mainProperty", "label.type", "isCurrentSort")
@attributeBindings("label.title:title")
export default class AdminReportTableHeader extends Component {
  @computed("currentSortLabel.sortProperty", "label.sortProperty")
  get isCurrentSort() {
    return this.currentSortLabel?.sortProperty === this.label?.sortProperty;
  }

  @computed("currentSortDirection")
  get sortIcon() {
    return this.currentSortDirection === 1 ? "caret-up" : "caret-down";
  }

  <template>
    {{#if this.showSortingUI}}
      <DButton
        @action={{this.sortByLabel}}
        @icon={{this.sortIcon}}
        class="sort-btn"
      />
    {{/if}}

    {{#if this.label.htmlTitle}}
      <span class="title">{{htmlSafe this.label.htmlTitle}}</span>
    {{else}}
      <span class="title">{{this.label.title}}</span>
    {{/if}}
  </template>
}
