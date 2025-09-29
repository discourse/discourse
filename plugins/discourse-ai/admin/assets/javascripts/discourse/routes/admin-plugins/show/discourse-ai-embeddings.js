import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiAiEmbeddingsRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("ai-embedding");
  }
}
