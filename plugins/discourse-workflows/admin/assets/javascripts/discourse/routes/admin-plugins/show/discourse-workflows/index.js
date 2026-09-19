import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsIndexRoute extends DiscourseRoute {
  @service store;

  async model() {
    const [workflows, workflowTags] = await Promise.all([
      this.store.findAll("discourse-workflows-workflow"),
      ajax("/admin/plugins/discourse-workflows/workflow-tags.json"),
    ]);
    return { workflows, workflowTags: workflowTags.workflow_tags };
  }
}
