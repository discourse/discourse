import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import SiteTrafficExplorerDimensionLabel from "discourse/admin/components/site-traffic-explorer-dimension-label";
import SiteTrafficExplorerPageviewCount from "discourse/admin/components/site-traffic-explorer-pageview-count";
import { countryName } from "discourse/admin/lib/format-country";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

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
  filterLabel(row) {
    const label =
      this.args.model.dimension === "countries"
        ? countryName(row.value)
        : row.label;

    return i18n("admin.site_traffic_explorer.filter_by", {
      label,
      count: row.pageviews,
    });
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
        <table class="d-table">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell" scope="col">
                {{@model.columnLabel}}
              </th>
              <th
                class="d-table__header-cell site-traffic-breakdown-modal__pageviews"
                scope="col"
              >{{i18n "admin.site_traffic_explorer.pageviews"}}</th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each this.rows as |row|}}
              <tr class="d-table__row">
                <td
                  class="d-table__cell --overview site-traffic-breakdown-modal__dimension"
                >
                  <div class="site-traffic-breakdown-modal__dimension-content">
                    <input
                      type="checkbox"
                      aria-label={{this.filterLabel row}}
                      checked={{this.isSelected row}}
                      {{on "change" (fn this.toggleFilter row)}}
                    />
                    {{#let (@model.rowLink row) as |rowLink|}}
                      {{#if rowLink}}
                        <a
                          href={{rowLink.href}}
                          rel={{rowLink.rel}}
                          target={{rowLink.target}}
                          class="site-traffic-explorer__row-link"
                        >
                          <SiteTrafficExplorerDimensionLabel
                            @dimension={{@model.dimension}}
                            @row={{row}}
                          />
                        </a>
                      {{else}}
                        <SiteTrafficExplorerDimensionLabel
                          @dimension={{@model.dimension}}
                          @row={{row}}
                        />
                      {{/if}}
                    {{/let}}
                  </div>
                </td>
                <td
                  class="d-table__cell --detail site-traffic-breakdown-modal__pageviews"
                >
                  <div class="d-table__mobile-label">
                    {{i18n "admin.site_traffic_explorer.pageviews"}}
                  </div>
                  <SiteTrafficExplorerPageviewCount
                    @value={{row.pageviews}}
                    as |formattedValue|
                  >
                    <span>{{formattedValue}}</span>
                  </SiteTrafficExplorerPageviewCount>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.applyFilters}}
          @label="admin.site_traffic_explorer.apply_filters"
        />
      </:footer>
    </DModal>
  </template>
}
