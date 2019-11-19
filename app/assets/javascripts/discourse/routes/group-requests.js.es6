import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("groups.requests.title");
  },

  model(params) {
    this._params = params;
    return this.modelFor("group");
  },

  setupController(controller, model) {
    this.controllerFor("group").set("showing", "requests");

    controller.setProperties({
      model,
      filterInput: this._params.filter
    });

    controller.refreshRequesters(true);
  }
});
