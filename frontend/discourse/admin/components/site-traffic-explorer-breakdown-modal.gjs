import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import SiteTrafficExplorerBreakdownRow from "discourse/admin/components/site-traffic-explorer-breakdown-row";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

export default class SiteTrafficExplorerBreakdownModal extends Component {
  @tracked selectedValues = [];

  constructor() {
    super(...arguments);
    this.selectedValues = [...this.args.model.selectedValues];
  }

  get rows() {
    return this.args.model.rows.slice(0, 50);
  }

  @action
  toggleFilter(row) {
    this.selectedValues = this.selectedValues.includes(row.value)
      ? this.selectedValues.filter((value) => value !== row.value)
      : [...this.selectedValues, row.value];
  }

  @action
  isSelected(row) {
    return this.selectedValues.includes(row.value);
  }

  @action
  applyFilters() {
    this.args.closeModal({
      filterRows: this.rows.filter((row) => this.isSelected(row)),
    });
  }

  <template>
    <DModal
      @title={{@model.title}}
      @closeModal={{@closeModal}}
      class="site-traffic-breakdown-modal"
    >
      <:body>
        <ul class="site-traffic-explorer__breakdown-list">
          {{#each this.rows as |row index|}}
            <li>
              <SiteTrafficExplorerBreakdownRow
                @row={{row}}
                @dimension={{@model.dimension}}
                @rowLink={{@model.rowLink row}}
                @inputId={{concat "site-traffic-expanded-filter-" index}}
                @checked={{this.isSelected row}}
                @onToggle={{fn this.toggleFilter row}}
              />
            </li>
          {{/each}}
        </ul>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.applyFilters}}
          @label="admin.site_traffic_explorer.apply"
        />
      </:footer>
    </DModal>
  </template>
}
