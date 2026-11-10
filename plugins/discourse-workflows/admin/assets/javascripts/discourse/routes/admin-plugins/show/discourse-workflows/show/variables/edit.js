import DiscourseRoute from "discourse/routes/discourse";

const WORKFLOW_ROUTE = "adminPlugins.show.discourse-workflows.show";

export default class DiscourseWorkflowsShowVariablesEditRoute extends DiscourseRoute {
  model(params) {
    return {
      ...this.modelFor(WORKFLOW_ROUTE),
      variableId: params.variable_id,
    };
  }
}
