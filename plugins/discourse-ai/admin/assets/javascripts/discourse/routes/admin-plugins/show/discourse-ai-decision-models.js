import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiDecisionModelsRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("ai-decision-model");
  }
}
