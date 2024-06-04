import DiscourseRoute from "discourse/routes/discourse";

export default class EditCategoryTabs extends DiscourseRoute {
  model() {
    return this.modelFor("editCategory");
  }

  setupController(controller, model, transition) {
    super.setupController(...arguments);

    const parentParams = this.paramsFor("editCategory");

    controller.setProperties({
      parentParams,
      selectedTab: transition.to.params.tab,
      showTooltip: false,
    });
  }
}
