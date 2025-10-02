import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiFeatures extends DiscourseRoute {
  @service store;

  async model() {
    return this.store.findAll("ai-feature");
  }
}
