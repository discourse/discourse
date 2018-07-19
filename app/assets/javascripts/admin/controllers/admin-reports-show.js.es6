import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  queryParams: ["start_date", "end_date", "category_id", "group_id"],
  categoryId: null,
  groupId: null,

  @computed("model.type")
  reportOptions(type) {
    let options = { table: { perPage: 50, limit: 50 } };

    if (type === "top_referred_topics") {
      options.table.limit = 10;
    }

    return options;
  },

  actions: {
    onSelectStartDate(startDate) {
      this.set("start_date", startDate);
    },

    onSelectCategory(categoryId) {
      this.set("category_id", categoryId);
    },

    onSelectGroup(groupId) {
      this.set("group_id", groupId);
    },

    onSelectEndDate(endDate) {
      this.set("end_date", endDate);
    }
  }
});
