import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsShowExecutionsShowRoute extends DiscourseRoute {
  async model(params) {
    const result = await ajax(
      `/admin/plugins/discourse-workflows/executions/${params.execution_id}`
    );
    return result.execution;
  }
}
