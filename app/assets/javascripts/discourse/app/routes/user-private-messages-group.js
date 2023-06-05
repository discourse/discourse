import DiscourseRoute from "discourse/routes/discourse";

export default class extends DiscourseRoute {
  model(params) {
    return this.modelFor("user").get("groups").filterBy("name", params.name)[0];
  }

  setupController(controller, model) {
    controller.set("group", model);
  }
}
