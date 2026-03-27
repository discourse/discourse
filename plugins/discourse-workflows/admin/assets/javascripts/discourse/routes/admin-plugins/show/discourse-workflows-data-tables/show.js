import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsDataTablesShowRoute extends DiscourseRoute {
  model(params) {
    return parseInt(params.id, 10);
  }
}
