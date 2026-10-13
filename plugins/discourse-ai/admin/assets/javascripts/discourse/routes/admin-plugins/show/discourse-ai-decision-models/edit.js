import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiDecisionModelsEdit extends DiscourseRoute {
  model(params) {
    const allDecisionModels = this.modelFor(
      "adminPlugins.show.discourse-ai-decision-models"
    );
    const id = parseInt(params.id, 10);
    return allDecisionModels.content.find((item) => item.id === id);
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allDecisionModels",
      this.modelFor("adminPlugins.show.discourse-ai-decision-models")
    );
  }
}
