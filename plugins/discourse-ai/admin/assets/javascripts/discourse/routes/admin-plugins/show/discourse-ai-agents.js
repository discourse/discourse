import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiAiAgentsRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("ai-agent");
  }
}
