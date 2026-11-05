import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiDecisionModelsNew extends DiscourseRoute {
  queryParams = {
    preset: { refreshModel: true },
  };

  model() {
    return this.store.createRecord("ai-decision-model");
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allDecisionModels",
      this.modelFor("adminPlugins.show.discourse-ai-decision-models")
    );
    controller.set("preset", this.paramsFor(this.routeName).preset || null);
  }
}
