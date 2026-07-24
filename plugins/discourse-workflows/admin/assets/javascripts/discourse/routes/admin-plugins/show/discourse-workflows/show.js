import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsShowRoute extends DiscourseRoute {
  @service store;

  async model(params) {
    const [workflow, stats] = await Promise.all([
      this.store.find("discourse-workflows-workflow", params.id),
      ajax(`/admin/plugins/discourse-workflows/stats/${params.id}.json`),
    ]);
    return { workflow, stats };
  }
}
