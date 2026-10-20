import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action, get } from "@ember/object";
import AdminReportTableHeader from "discourse/admin/components/admin-report-table-header";
import AdminReportTableRow from "discourse/admin/components/admin-report-table-row";
import { makeArray } from "discourse/lib/helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const PAGES_LIMIT = 8;

export default class AdminReportTable extends Component {
  @tracked page = 0;
  @tracked sortDirection = 1;
  @tracked sortLabel;

  get data() {
    return get(this.args.model, "data");
  }

  get perPage() {
    return this.args.options?.perPage;
  }

  get twoColumns() {
    return this.args.model?.computedLabels?.length === 2;
  }

  get showTotalForSample() {
    // check if we have at least one cell which contains a value
    const sum = this.totalsForSample
      .map((t) => t.value)
      .filter((item) => item != null)
      .reduce((s, v) => s + v, 0);

    return (
      sum >= 1 &&
      this.args.options?.total &&
      get(this.args.model, "dates_filtering")
    );
  }

  get showTotal() {
    return (
      get(this.args.model, "total") &&
      this.args.options?.total &&
      this.twoColumns
    );
  }

  get showAverage() {
    return (
      get(this.args.model, "average") &&
      this.data.length > 0 &&
      this.totalsForSample?.[1]?.value &&
      this.twoColumns
    );
  }

  get averageForSample() {
    const averageLabel = this.args.model.computedLabels.at(-1);
    return averageLabel.compute({
      y: (this.totalsForSample?.[1]?.value / this.data?.length).toFixed(0),
    }).formattedValue;
  }

  get showSortingUI() {
    return this.data?.length >= 5;
  }

  @cached
  get totalsForSample() {
    return this.args.model?.computedLabels?.map((label) => {
      const computedLabel = label.compute(this.totalsForSampleRow);
      computedLabel.type = label.type;
      computedLabel.property = label.mainProperty;
      return computedLabel;
    });
  }

  get formattedTotal() {
    const totalLabel = this.args.model?.computedLabels?.at(-1);
    return totalLabel.compute({ y: get(this.args.model, "total") })
      .formattedValue;
  }

  @cached
  get totalsForSampleRow() {
    const data = this.data;
    if (!data || !data.length) {
      return {};
    }

    let totalsRow = {};

    this.args.model?.computedLabels?.forEach((label) => {
      const reducer = (sum, row) => {
        const computedLabel = label.compute(row);
        const value = computedLabel.value;

        if (!["seconds", "number", "percent"].includes(label.type)) {
          return;
        } else {
          return sum + Math.round(value || 0);
        }
      };

      const total = data.reduce(reducer, 0);
      totalsRow[label.mainProperty] =
        label.type === "percent" ? Math.round(total / data.length) : total;
    });

    return totalsRow;
  }

  @cached
  get sortedData() {
    const data = makeArray(this.data);

    if (this.sortLabel) {
      const compare = (label, direction) => {
        return (a, b) => {
          const aValue = label.compute(a, { useSortProperty: true }).value;
          const bValue = label.compute(b, { useSortProperty: true }).value;
          const result = aValue < bValue ? -1 : aValue > bValue ? 1 : 0;
          return result * direction;
        };
      };

      return data.sort(compare(this.sortLabel, this.sortDirection));
    }

    return data;
  }

  get paginatedData() {
    if (this.perPage < this.sortedData?.length) {
      const start = this.perPage * this.page;
      return this.sortedData?.slice(start, start + this.perPage);
    }

    return this.sortedData;
  }

  get pages() {
    const data = this.data;
    if (!data || data.length <= this.perPage) {
      return [];
    }

    const pagesIndexes = [];
    for (let i = 0; i < Math.ceil(data.length / this.perPage); i++) {
      pagesIndexes.push(i);
    }

    let pages = pagesIndexes.map((v) => {
      return {
        page: v + 1,
        index: v,
        class: v === this.page ? "is-current" : null,
      };
    });

    if (pages.length > PAGES_LIMIT) {
      const before = Math.max(0, this.page - PAGES_LIMIT / 2);
      const after = Math.max(PAGES_LIMIT, this.page + PAGES_LIMIT / 2);
      pages = pages.slice(before, after);
    }

    return pages;
  }

  @action
  changePage(page) {
    this.page = page;
  }

  @action
  sortByLabel(label) {
    if (this.sortLabel === label) {
      this.sortDirection = this.sortDirection === 1 ? -1 : 1;
    } else {
      this.sortLabel = label;
    }
  }

  <template>
    <div
      class={{dConcatClass
        "admin-report-table"
        (if this.twoColumns "two-columns")
      }}
      ...attributes
    >
      <table class="table">
        <thead>
          <tr>
            {{#each @model.computedLabels as |label|}}
              <AdminReportTableHeader
                @currentSortDirection={{this.sortDirection}}
                @currentSortLabel={{this.sortLabel}}
                @label={{label}}
                @showSortingUI={{this.showSortingUI}}
                @sortByLabel={{fn this.sortByLabel label}}
              />
            {{else}}
              {{#each this.data as |data|}}
                <th>{{data.x}}</th>
              {{/each}}
            {{/each}}
          </tr>
        </thead>
        <tbody>
          {{#each this.paginatedData as |data|}}
            <AdminReportTableRow
              @data={{data}}
              @hasRelatedItems={{@hasRelatedItems}}
              @labels={{@model.computedLabels}}
              @options={{@options}}
              @reportFilters={{@reportFilters}}
              @reportType={{@reportType}}
            />
          {{/each}}

          {{#if this.showTotalForSample}}
            <tr class="total-row">
              <td colspan={{this.totalsForSample.length}}>
                {{i18n "admin.dashboard.reports.totals_for_sample"}}
              </td>
            </tr>
            <tr class="admin-report-table-row">
              {{#each this.totalsForSample as |total|}}
                <td
                  class="admin-report-table-cell
                    {{total.type}}
                    {{total.property}}"
                >
                  {{total.formattedValue}}
                </td>
              {{/each}}
            </tr>
          {{/if}}

          {{#if this.showTotal}}
            <tr class="total-row">
              <td colspan="2">
                {{i18n "admin.dashboard.reports.total"}}
              </td>
            </tr>
            <tr class="admin-report-table-row">
              <td class="admin-report-table-cell date x">—</td>
              <td
                class="admin-report-table-cell number y"
              >{{this.formattedTotal}}</td>
            </tr>
          {{/if}}

          {{#if this.showAverage}}
            <tr class="total-row">
              <td colspan="2">
                {{i18n "admin.dashboard.reports.average_for_sample"}}
              </td>
            </tr>
            <tr class="admin-report-table-row">
              <td class="admin-report-table-cell date x">—</td>
              <td
                class="admin-report-table-cell number y"
              >{{this.averageForSample}}</td>
            </tr>
          {{/if}}
        </tbody>
      </table>

      <div class="pagination">
        {{#each this.pages as |pageState|}}
          <DButton
            class={{pageState.class}}
            @action={{fn this.changePage pageState.index}}
            @translatedLabel={{pageState.page}}
          />
        {{/each}}
      </div>
    </div>
  </template>
}
