import DiscourseRoute from "discourse/routes/discourse";

const WORKFLOW_ROUTE = "adminPlugins.show.discourse-workflows.show";

export default class DiscourseWorkflowsShowNodeRoute extends DiscourseRoute {
  model(params) {
    return {
      ...this.modelFor(WORKFLOW_ROUTE),
      initialNodeId: params.node_id,
    };
  }
}
