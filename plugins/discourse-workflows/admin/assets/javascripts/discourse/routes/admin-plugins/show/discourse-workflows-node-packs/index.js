import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsNodePacksIndexRoute extends DiscourseRoute {
  model() {
    return this.modelFor("adminPlugins.show.discourse-workflows-node-packs");
  }
}
