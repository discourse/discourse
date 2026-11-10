import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsShowVariablesIndexRoute extends DiscourseRoute {
  model() {
    return this.modelFor("adminPlugins.show.discourse-workflows.show");
  }
}
