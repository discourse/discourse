import DiscourseRoute from "discourse/routes/discourse";
import { longDate } from "discourse/lib/formatter";

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
    // If we refresh via `refreshModel` set the old model to loading
    this._params = params;
    return this.store.find("directoryItem", params);
  },

  setupController(controller, model) {
    const params = this._params;
    const lastUpdatedAt = model.get("resultSetMeta.last_updated_at");
    controller.setProperties({
      model,
      lastUpdatedAt: lastUpdatedAt ? longDate(lastUpdatedAt) : null,
      period: params.period,
      nameInput: params.name
    });
  },

  actions: {
    didTransition() {
      this.controllerFor("users")._showFooter();
      return true;
    }
  }
});
