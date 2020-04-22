import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  noContentHelpKey: "user_activity.no_bookmarks",

  queryParams: {
    acting_username: { refreshModel: true }
  },

  model() {
    return this.modelFor("user").get("bookmarks");
  },

  renderTemplate() {
    this.render("user_bookmarks");
  },

  setupController(controller, model) {
    controller.set("model", model);
    controller.loadItems();
  },

  actions: {
    didTransition() {
      this.controllerFor("user-activity")._showFooter();
      return true;
    }
  }
});
