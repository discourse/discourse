import Component from "@glimmer/component";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class QueryChartEmptyState extends Component {
  get message() {
    if (this.args.reason === "no-rows") {
      return i18n("explorer.chart_empty.no_rows");
    }
    const cols = this.args.ignoredColumns ?? [];
    if (cols.length) {
      return i18n("explorer.chart_empty.no_numeric_with_columns", {
        columns: cols.join(", "),
      });
    }
    return i18n("explorer.chart_empty.no_numeric");
  }

  <template>
    <div class="query-chart-empty-state">
      {{dIcon "chart-line" class="query-chart-empty-state__icon"}}
      <p class="query-chart-empty-state__message">{{this.message}}</p>
      <DButton
        @action={{@onViewAsTable}}
        @label="explorer.chart_empty.view_as_table"
        @icon="table"
        class="btn-default query-chart-empty-state__view-table"
      />
    </div>
  </template>
}
