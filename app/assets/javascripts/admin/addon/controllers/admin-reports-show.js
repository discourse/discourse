import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  queryParams: ["start_date", "end_date", "filters", "chart_grouping", "mode"],
  start_date: null,
  end_date: null,
  filters: null,
  chart_grouping: null,

  @discourseComputed("model.type")
  reportOptions(type) {
    let options = { table: { perPage: 50, limit: 50, formatNumbers: false } };

    if (type === "top_referred_topics") {
      options.table.limit = 10;
    }

    options.chartGrouping = this.chart_grouping;

    return options;
  },
});
