import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class WorkflowsFormTestRoute extends DiscourseRoute {
  async model(params) {
    return await ajax(`/workflows/form-test/${params.token}.json`);
  }
}
