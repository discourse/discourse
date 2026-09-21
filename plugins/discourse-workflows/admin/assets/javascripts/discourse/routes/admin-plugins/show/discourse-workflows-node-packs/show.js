import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsNodePacksShowRoute extends DiscourseRoute {
  model(params) {
    return parseInt(params.id, 10);
  }
}
