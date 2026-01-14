import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiToolsRoute extends DiscourseRoute {
  @service store;

  model() {
    return this.store.findAll("ai-tool");
  }
}
