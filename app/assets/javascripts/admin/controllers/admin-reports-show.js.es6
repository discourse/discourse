import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  queryParams: ["start_date", "end_date", "filters"],
  start_date: null,
  end_date: null,
  filters: null,

  @computed("model.type")
  reportOptions(type) {
    let options = { table: { perPage: 50, limit: 50, formatNumbers: false } };

    if (type === "top_referred_topics") {
      options.table.limit = 10;
    }

    return options;
  }
});
