import Controller from "@ember/controller";
import discourseComputed from "discourse/lib/decorators";

export default class AdminReportsShowController extends Controller {
  queryParams = ["start_date", "end_date", "filters", "chart_grouping", "mode"];
  start_date = null;
  end_date = null;
  filters = null;
  chart_grouping = null;

  @discourseComputed("model.type")
  reportOptions(type) {
    let options = { table: { perPage: 50, limit: 50, formatNumbers: false } };

    if (type === "top_referred_topics") {
      options.table.limit = 10;
    }

    if (type === "site_traffic") {
      options.stackedChart = {
        hiddenLabels: ["page_view_other", "page_view_crawler"],
      };
    }

    options.chartGrouping = this.chart_grouping;

    return options;
  }
}
