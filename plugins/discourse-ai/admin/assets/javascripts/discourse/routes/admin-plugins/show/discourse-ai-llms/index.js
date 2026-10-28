import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiLlmsIndex extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminPlugins.show.discourse-ai-models.index", {
      queryParams: { type: "llm" },
    });
  }
}
