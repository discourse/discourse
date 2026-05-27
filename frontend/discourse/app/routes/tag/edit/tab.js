import Route from "@ember/routing/route";

export default class TagEditTabRoute extends Route {
  model(params) {
    this.controllerFor("tag.edit").set("selectedTab", params.tab);
    return this.modelFor("tag.edit");
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setProperties({
      model,
      parentParams: this.paramsFor("tag.edit"),
    });
  }
}
