import Controller from "@ember/controller";
import { computed } from "@ember/object";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class AdminReportsShowController extends Controller {
  queryParams = applyValueTransformer("admin-reports-show-query-params", [
    "start_date",
    "end_date",
    "filters",
    "chart_grouping",
    "mode",
  ]);
  start_date = null;
  end_date = null;
  filters = null;
  chart_grouping = null;

  @computed("model.type")
  get reportOptions() {
    let options = { table: { perPage: 50, limit: 50 } };

    if (this.model?.type === "top_referred_topics") {
      options.table.limit = 10;
    }

    if (this.model?.type === "site_traffic") {
      options.stackedChart = {
        hiddenLabels: ["page_view_other", "page_view_crawler"],
      };
    }

    options.chartGrouping = this.chart_grouping;

    return options;
  }
}
