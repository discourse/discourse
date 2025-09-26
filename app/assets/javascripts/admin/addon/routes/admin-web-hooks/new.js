import DiscourseRoute from "discourse/routes/discourse";

export default class AdminWebHooksNewRoute extends DiscourseRoute {
  model() {
    return this.store.createRecord("web-hook");
  }
}
