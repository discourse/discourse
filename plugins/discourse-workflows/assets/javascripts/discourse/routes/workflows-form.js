import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class WorkflowsFormRoute extends DiscourseRoute {
  async model(params) {
    return await ajax(`/workflows/form/${params.uuid}.json`);
  }
}
