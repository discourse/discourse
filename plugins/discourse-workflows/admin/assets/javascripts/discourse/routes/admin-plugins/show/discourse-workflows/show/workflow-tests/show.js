import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsShowTestsShowRoute extends DiscourseRoute {
  model(params) {
    return {
      ...this.modelFor("adminPlugins.show.discourse-workflows.show"),
      testId: params.test_id,
    };
  }
}
