import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";

export default Controller.extend({
  queryParams: ["start_date", "end_date", "filters"],
  start_date: null,
  end_date: null,
  filters: null,

  @discourseComputed("model.type")
  reportOptions(type) {
    let options = { table: { perPage: 50, limit: 50, formatNumbers: false } };

    if (type === "top_referred_topics") {
      options.table.limit = 10;
    }

    return options;
  }
});
