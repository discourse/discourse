import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiAiPersonasRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("ai-persona");
  }
}
