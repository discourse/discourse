import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class extends DiscourseRoute {
  @service router;

  model(params) {
    return this.modelFor("user")
      .get("groups")
      .find((group) => {
        return group.name.toLowerCase() === params.name.toLowerCase();
      });
  }

  afterModel(model) {
    if (!model) {
      this.router.transitionTo("exception-unknown");
      return;
    }
  }

  setupController(controller, model) {
    controller.set("group", model);
  }
}
