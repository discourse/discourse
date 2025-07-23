import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiAiLlmsRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("ai-llm");
  }
}
