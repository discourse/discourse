import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminPluginsShowDiscourseAiConceptsIndexController extends Controller {
  @tracked status = "all";

  @tracked filter = "";
  @tracked order = "usage";
  queryParams = ["status", "filter", "order"];

  @action
  updateQuery(updates) {
    if ("status" in updates) {
      this.status = updates.status || "all";
    }

    if ("filter" in updates) {
      this.filter = updates.filter ?? "";
    }

    if ("order" in updates) {
      this.order = updates.order || "usage";
    }
  }
}
