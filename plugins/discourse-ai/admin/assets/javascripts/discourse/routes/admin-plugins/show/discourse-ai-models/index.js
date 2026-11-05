import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiModelsIndex extends DiscourseRoute {
  queryParams = {
    type: { refreshModel: true },
  };

  model() {
    return this.modelFor("adminPlugins.show.discourse-ai-models");
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("type", this.paramsFor(this.routeName).type || null);
  }
}
