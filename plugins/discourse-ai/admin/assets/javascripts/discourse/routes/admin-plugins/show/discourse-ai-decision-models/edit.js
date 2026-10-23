import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiDecisionModelsEdit extends DiscourseRoute {
  model(params) {
    const id = parseInt(params.id, 10);
    return this.modelFor(
      "adminPlugins.show.discourse-ai-decision-models"
    ).content.find((decisionModel) => decisionModel.id === id);
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allDecisionModels",
      this.modelFor("adminPlugins.show.discourse-ai-decision-models")
    );
  }
}
