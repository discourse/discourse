import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { i18n } from "discourse-i18n";
import { chartability, chartDatasets, hasDates } from "../lib/chart-helpers";
import DataExplorerChart from "./data-explorer-chart";

export default class DataExplorerAdminDashboardCard extends Component {
  get rows() {
    return this.args.payload?.rows ?? [];
  }

  get columns() {
    return this.args.payload?.columns ?? [];
  }

  get columnLabels() {
    return this.columns.map((col) => col.replaceAll("_", " "));
  }

  @cached
  get chartability() {
    return chartability(this.args.payload);
  }

  get isChartable() {
    return this.columns.length === 2 && this.chartability.chartable;
  }

  @cached
  get hasDates() {
    return hasDates(this.rows);
  }

  get chartType() {
    if (this.chartability.numericIndices.length > 1) {
      return "bar";
    }
    return this.hasDates ? "line" : "bar";
  }

  get isStacked() {
    return this.chartability.numericIndices.length > 1 && this.hasDates;
  }

  get chartLabels() {
    return this.rows.map((row) => row[0]);
  }

  get chartDatasets() {
    return chartDatasets(
      this.rows,
      this.chartability.numericIndices,
      this.columnLabels
    );
  }

  <template>
    <div class="de-dashboard-card">
      {{#if this.rows.length}}
        {{#if this.isChartable}}
          <DataExplorerChart
            @chartType={{this.chartType}}
            @datasets={{this.chartDatasets}}
            @labels={{this.chartLabels}}
            @stacked={{this.isStacked}}
          />
        {{else}}
          <table class="de-dashboard-card__table">
            <thead>
              <tr>
                {{#each this.columnLabels as |col|}}
                  <th>{{col}}</th>
                {{/each}}
              </tr>
            </thead>
            <tbody>
              {{#each this.rows as |row|}}
                <tr>
                  {{#each row as |cell|}}
                    <td>{{cell}}</td>
                  {{/each}}
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}
      {{else}}
        <div class="de-dashboard-card__empty">
          {{i18n "data_explorer.admin_dashboard_card.no_results"}}
        </div>
      {{/if}}
    </div>
  </template>
}
