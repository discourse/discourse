import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  noContentHelpKey: "user_activity.no_bookmarks",

  queryParams: {
    acting_username: { refreshModel: true }
  },

  model() {
    return this.modelFor("user").get("bookmarks");
  },

  afterModel(model) {
    return model.loadItems();
  },

  renderTemplate() {
    this.render("user_bookmarks");
  },

  setupController(controller, model) {
    controller.set("model", model);
  },

  actions: {
    didTransition() {
      this.controllerFor("user-activity")._showFooter();
      return true;
    }
  }
});
