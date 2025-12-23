/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action, computed } from "@ember/object";
import { alias } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import AdminReportTableHeader from "discourse/admin/components/admin-report-table-header";
import AdminReportTableRow from "discourse/admin/components/admin-report-table-row";
import DButton from "discourse/components/d-button";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";

const PAGES_LIMIT = 8;

@classNameBindings("sortable", "twoColumns")
@classNames("admin-report-table")
export default class AdminReportTable extends Component {
  sortable = false;
  sortDirection = 1;

  @alias("options.perPage") perPage;

  page = 0;

  @computed("model.computedLabels.length")
  get twoColumns() {
    return this.model?.computedLabels?.length === 2;
  }

  @computed(
    "totalsForSample",
    "options.total",
    "model.dates_filtering"
  )
  get showTotalForSample() {
    // check if we have at least one cell which contains a value
    const sum = this.totalsForSample
      .map((t) => t.value)
      .filter((item) => item != null)
      .reduce((s, v) => s + v, 0);

    return sum >= 1 && this.options?.total && this.model?.dates_filtering;
  }

  @computed("model.total", "options.total", "twoColumns")
  get showTotal() {
    return this.model?.total && this.options?.total && this.twoColumns;
  }

  @computed(
    "model.{average,data}",
    "totalsForSample.1.value",
    "twoColumns"
  )
  get showAverage() {
    return (
      this.model?.average &&
      this.model?.data.length > 0 &&
      this.totalsForSample?.[1]?.value &&
      this.twoColumns
    );
  }

  @computed("totalsForSample.1.value", "model.data.length")
  get averageForSample() {
    const averageLabel = this.model.computedLabels.at(-1);
    return averageLabel.compute({ y: (this.totalsForSample?.[1]?.value / this.model?.data?.length).toFixed(0) })
      .formattedValue;
  }

  @computed("model.data.length")
  get showSortingUI() {
    return this.model?.data?.length >= 5;
  }

  @computed("totalsForSampleRow", "model.computedLabels")
  get totalsForSample() {
    return this.model?.computedLabels?.map((label) => {
      const computedLabel = label.compute(this.totalsForSampleRow);
      computedLabel.type = label.type;
      computedLabel.property = label.mainProperty;
      return computedLabel;
    });
  }

  @computed("model.total", "model.computedLabels")
  get formattedTotal() {
    const totalLabel = this.model?.computedLabels?.at(-1);
    return totalLabel.compute({ y: this.model?.total }).formattedValue;
  }

  @computed("model.data", "model.computedLabels")
  get totalsForSampleRow() {
    if (!this.model?.data || !this.model?.data?.length) {
      return {};
    }

    let totalsRow = {};

    this.model?.computedLabels?.forEach((label) => {
      const reducer = (sum, row) => {
        const computedLabel = label.compute(row);
        const value = computedLabel.value;

        if (!["seconds", "number", "percent"].includes(label.type)) {
          return;
        } else {
          return sum + Math.round(value || 0);
        }
      };

      const total = this.model?.data?.reduce(reducer, 0);
      totalsRow[label.mainProperty] =
        label.type === "percent" ? Math.round(total / this.model?.data?.length) : total;
    });

    return totalsRow;
  }

  @computed("sortLabel", "sortDirection", "model.data.[]")
  get sortedData() {
    const data = makeArray(this.model?.data);

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

  @computed("sortedData.[]", "perPage", "page")
  get paginatedData() {
    if (this.perPage < this.sortedData?.length) {
      const start = this.perPage * this.page;
      return this.sortedData?.slice(start, start + this.perPage);
    }

    return this.sortedData;
  }

  @computed("model.data", "perPage", "page")
  get pages() {
    if (!this.model?.data || this.model?.data?.length <= this.perPage) {
      return [];
    }

    const pagesIndexes = [];
    for (let i = 0; i < Math.ceil(this.model?.data?.length / this.perPage); i++) {
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
    this.set("page", page);
  }

  @action
  sortByLabel(label) {
    if (this.sortLabel === label) {
      this.set("sortDirection", this.sortDirection === 1 ? -1 : 1);
    } else {
      this.set("sortLabel", label);
    }
  }

  <template>
    <table class="table">
      <thead>
        <tr>
          {{#each this.model.computedLabels as |label|}}
            <AdminReportTableHeader
              @showSortingUI={{this.showSortingUI}}
              @currentSortDirection={{this.sortDirection}}
              @currentSortLabel={{this.sortLabel}}
              @label={{label}}
              @sortByLabel={{fn this.sortByLabel label}}
            />
          {{else}}
            {{#each this.model.data as |data|}}
              <th>{{data.x}}</th>
            {{/each}}
          {{/each}}
        </tr>
      </thead>
      <tbody>
        {{#each this.paginatedData as |data|}}
          <AdminReportTableRow
            @data={{data}}
            @labels={{this.model.computedLabels}}
            @options={{this.options}}
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
          @translatedLabel={{pageState.page}}
          @action={{fn this.changePage pageState.index}}
          class={{pageState.class}}
        />
      {{/each}}
    </div>
  </template>
}
