import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    return this.modelFor("editCategory");
  },

  setupController(controller, model, transition) {
    this._super(...arguments);

    const parentParams = this.paramsFor("editCategory");

    controller.setProperties({
      parentParams,
      selectedTab: transition.to.params.tab,
      showTooltip: false,
    });
  },
});
