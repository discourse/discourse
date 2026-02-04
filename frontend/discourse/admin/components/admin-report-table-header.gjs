import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class AdminReportTableHeader extends Component {
  get isCurrentSort() {
    return (
      this.args.currentSortLabel?.sortProperty === this.args.label?.sortProperty
    );
  }

  get sortIcon() {
    return this.args.currentSortDirection === 1 ? "angle-up" : "angle-down";
  }

  get sortButtonTitle() {
    const labelTitle = this.args.label?.title;
    if (this.isCurrentSort) {
      const direction =
        this.args.currentSortDirection === 1 ? "ascending" : "descending";
      return i18n("admin.dashboard.reports.sort_button_current", {
        column: labelTitle,
        direction: i18n(`admin.dashboard.reports.sort_${direction}`),
      });
    }
    return i18n("admin.dashboard.reports.sort_button", { column: labelTitle });
  }

  get thClass() {
    const classes = ["admin-report-table-header"];
    if (this.args.label?.mainProperty) {
      classes.push(this.args.label.mainProperty);
    }
    if (this.args.label?.type) {
      classes.push(this.args.label.type);
    }
    if (this.isCurrentSort) {
      classes.push("is-current-sort");
    }
    return classes.join(" ");
  }

  <template>
    <th class={{this.thClass}} title={{@label.title}}>
      {{#if @showSortingUI}}
        <DButton
          @action={{@sortByLabel}}
          @icon={{this.sortIcon}}
          @translatedLabel={{@label.title}}
          @translatedTitle={{this.sortButtonTitle}}
          class="btn-primary btn-transparent sort-btn"
        />
      {{else if @label.htmlTitle}}
        <span class="title">{{htmlSafe @label.htmlTitle}}</span>
      {{else}}
        <span class="title">{{@label.title}}</span>
      {{/if}}
    </th>
  </template>
}
