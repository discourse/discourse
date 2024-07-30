import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class GroupRequests extends DiscourseRoute {
  titleToken() {
    return I18n.t("groups.requests.title");
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
