import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupRequests extends DiscourseRoute {
  titleToken() {
    return i18n("groups.requests.title");
  }

  model(params) {
    this._params = params;
    return this.modelFor("group");
  }

  setupController(controller, model) {
    this.controllerFor("group").set("showing", "requests");

    controller.setProperties({
      model,
      filterInput: this._params.filter,
    });

    controller.findRequesters(true);
  }
}
