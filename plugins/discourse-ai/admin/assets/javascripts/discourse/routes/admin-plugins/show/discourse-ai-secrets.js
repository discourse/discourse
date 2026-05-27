import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiAiSecretsRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("ai-secret");
  }
}
