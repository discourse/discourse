import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import discourseComputed from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";
import AdminReportTableHeader from "admin/components/admin-report-table-header";
import AdminReportTableRow from "admin/components/admin-report-table-row";

const PAGES_LIMIT = 8;

@classNameBindings("sortable", "twoColumns")
@classNames("admin-report-table")
export default class AdminReportTable extends Component {
  sortable = false;
  sortDirection = 1;

  @alias("options.perPage") perPage;

  page = 0;

  @discourseComputed("model.computedLabels.length")
  twoColumns(labelsLength) {
    return labelsLength === 2;
  }

  @discourseComputed(
    "totalsForSample",
    "options.total",
    "model.dates_filtering"
  )
  showTotalForSample(totalsForSample, total, datesFiltering) {
    // check if we have at least one cell which contains a value
    const sum = totalsForSample
      .map((t) => t.value)
      .compact()
      .reduce((s, v) => s + v, 0);

    return sum >= 1 && total && datesFiltering;
  }

  @discourseComputed("model.total", "options.total", "twoColumns")
  showTotal(reportTotal, total, twoColumns) {
    return reportTotal && total && twoColumns;
  }

  @discourseComputed(
    "model.{average,data}",
    "totalsForSample.1.value",
    "twoColumns"
  )
  showAverage(model, sampleTotalValue, hasTwoColumns) {
    return (
      model.average &&
      model.data.length > 0 &&
      sampleTotalValue &&
      hasTwoColumns
    );
  }

  @discourseComputed("totalsForSample.1.value", "model.data.length")
  averageForSample(totals, count) {
    const averageLabel = this.model.computedLabels.at(-1);
    return averageLabel.compute({ y: (totals / count).toFixed(0) })
      .formattedValue;
  }

  @discourseComputed("model.data.length")
  showSortingUI(dataLength) {
    return dataLength >= 5;
  }

  @discourseComputed("totalsForSampleRow", "model.computedLabels")
  totalsForSample(row, labels) {
    return labels.map((label) => {
      const computedLabel = label.compute(row);
      computedLabel.type = label.type;
      computedLabel.property = label.mainProperty;
      return computedLabel;
    });
  }

  @discourseComputed("model.total", "model.computedLabels")
  formattedTotal(total, labels) {
    const totalLabel = labels.at(-1);
    return totalLabel.compute({ y: total }).formattedValue;
  }

  @discourseComputed("model.data", "model.computedLabels")
  totalsForSampleRow(rows, labels) {
    if (!rows || !rows.length) {
      return {};
    }

    let totalsRow = {};

    labels.forEach((label) => {
      const reducer = (sum, row) => {
        const computedLabel = label.compute(row);
        const value = computedLabel.value;

        if (!["seconds", "number", "percent"].includes(label.type)) {
          return;
        } else {
          return sum + Math.round(value || 0);
        }
      };

      const total = rows.reduce(reducer, 0);
      totalsRow[label.mainProperty] =
        label.type === "percent" ? Math.round(total / rows.length) : total;
    });

    return totalsRow;
  }

  @discourseComputed("sortLabel", "sortDirection", "model.data.[]")
  sortedData(sortLabel, sortDirection, data) {
    data = makeArray(data);

    if (sortLabel) {
      const compare = (label, direction) => {
        return (a, b) => {
          const aValue = label.compute(a, { useSortProperty: true }).value;
          const bValue = label.compute(b, { useSortProperty: true }).value;
          const result = aValue < bValue ? -1 : aValue > bValue ? 1 : 0;
          return result * direction;
        };
      };

      return data.sort(compare(sortLabel, sortDirection));
    }

    return data;
  }

  @discourseComputed("sortedData.[]", "perPage", "page")
  paginatedData(data, perPage, page) {
    if (perPage < data.length) {
      const start = perPage * page;
      return data.slice(start, start + perPage);
    }

    return data;
  }

  @discourseComputed("model.data", "perPage", "page")
  pages(data, perPage, page) {
    if (!data || data.length <= perPage) {
      return [];
    }

    const pagesIndexes = [];
    for (let i = 0; i < Math.ceil(data.length / perPage); i++) {
      pagesIndexes.push(i);
    }

    let pages = pagesIndexes.map((v) => {
      return {
        page: v + 1,
        index: v,
        class: v === page ? "is-current" : null,
      };
    });

    if (pages.length > PAGES_LIMIT) {
      const before = Math.max(0, page - PAGES_LIMIT / 2);
      const after = Math.max(PAGES_LIMIT, page + PAGES_LIMIT / 2);
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
          {{#if this.model.computedLabels}}
            {{#each this.model.computedLabels as |label|}}
              <AdminReportTableHeader
                @showSortingUI={{this.showSortingUI}}
                @currentSortDirection={{this.sortDirection}}
                @currentSortLabel={{this.sortLabel}}
                @label={{label}}
                @sortByLabel={{fn this.sortByLabel label}}
              />
            {{/each}}
          {{else}}
            {{#each this.model.data as |data|}}
              <th>{{data.x}}</th>
            {{/each}}
          {{/if}}
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
