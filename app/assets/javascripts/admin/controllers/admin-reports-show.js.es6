import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  queryParams: ["start_date", "end_date", "category_id", "group_id"],

  @computed("model.type")
  reportOptions(type) {
    let options = { table: { perPage: 50, limit: 50, formatNumbers: false } };

    if (type === "top_referred_topics") {
      options.table.limit = 10;
    }

    return options;
  },

  @computed("category_id", "group_id", "start_date", "end_date")
  filters(categoryId, groupId, startDate, endDate) {
    return {
      categoryId,
      groupId,
      startDate,
      endDate
    };
  },

  actions: {
    onParamsChange(params) {
      this.setProperties({
        start_date: params.startDate,
        category_id: params.categoryId,
        group_id: params.groupId,
        end_date: params.endDate
      });
    }
  }
});
