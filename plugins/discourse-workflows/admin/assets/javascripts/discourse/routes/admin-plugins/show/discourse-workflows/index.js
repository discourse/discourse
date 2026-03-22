import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsIndexRoute extends DiscourseRoute {
  @service store;

  async model() {
    const [workflows, stats] = await Promise.all([
      this.store.findAll("discourse-workflows-workflow"),
      ajax("/admin/plugins/discourse-workflows/stats.json"),
    ]);
    return { workflows, stats };
  }
}
