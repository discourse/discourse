import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  queryParams: {
    period: { refreshModel: true },
    order: { refreshModel: true },
    asc: { refreshModel: true },
    name: { refreshModel: true, replace: true },
    group: { refreshModel: true },
    exclude_usernames: { refreshModel: true }
  },

  titleToken() {
    return I18n.t("directory.title");
  },

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.setProperties({
        period: "weekly",
        order: "likes_received",
        asc: null,
        name: "",
        group: null,
        exclude_usernames: null,
        lastUpdatedAt: null
      });
    }
  },

  beforeModel() {
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      this.replaceWith("discovery");
    }
  },

  model(params) {
    return params;
  },

  setupController(controller, params) {
    controller.loadUsers(params);
  },

  actions: {
    didTransition() {
      this.controllerFor("users")._showFooter();
      return true;
    }
  }
});
