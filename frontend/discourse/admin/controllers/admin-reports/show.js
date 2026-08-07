import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { computed } from "@ember/object";
import { applyValueTransformer } from "discourse/lib/transformer";

const DEFAULT_BACK_LINK = {
  route: "adminReports",
  label: "admin.reports.back",
};

export default class AdminReportsShowController extends Controller {
  @tracked backLink = DEFAULT_BACK_LINK;
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

  setBackLink({ route, query, label }) {
    this.backLink = { route, query, label };
  }

  resetBackLink() {
    this.backLink = DEFAULT_BACK_LINK;
  }

  @computed("model.type")
  get reportOptions() {
    let options = { table: { perPage: 50, limit: 50 } };

    if (this.model?.type === "top_referred_topics") {
      options.table.limit = 10;
    }

    if (this.model?.type === "site_traffic") {
      options.stackedChart = {
        hiddenLabels: [
          "page_view_other",
          "page_view_crawler",
          "page_view_embed",
        ],
      };
    }

    options.chartGrouping = this.chart_grouping;

    return options;
  }
}
