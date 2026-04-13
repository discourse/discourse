import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsTemplatesRoute extends DiscourseRoute {
  async model() {
    return ajax("/admin/plugins/discourse-workflows/templates.json");
  }
}
