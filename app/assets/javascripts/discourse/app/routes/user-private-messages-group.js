import DiscourseRoute from "discourse/routes/discourse";

export default class extends DiscourseRoute {
  model(params) {
    return this.modelFor("user")
      .get("groups")
      .find((group) => {
        return group.name.toLowerCase() === params.name.toLowerCase();
      });
  }

  afterModel(model) {
    if (!model) {
      this.transitionTo("exception-unknown");
      return;
    }
  }

  setupController(controller, model) {
    controller.set("group", model);
  }
}
