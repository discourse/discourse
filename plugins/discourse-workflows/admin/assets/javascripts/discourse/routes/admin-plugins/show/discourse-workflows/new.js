import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseWorkflowsNewRoute extends DiscourseRoute {
  @service store;

  model() {
    return this.store.createRecord("discourse-workflows-workflow", {
      name: "",
      enabled: false,
      nodes: [],
      connections: [],
    });
  }
}
