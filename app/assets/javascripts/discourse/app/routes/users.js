import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { Promise } from "rsvp";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  queryParams: {
    period: { refreshModel: true },
    order: { refreshModel: true },
    asc: { refreshModel: true },
    name: { refreshModel: false, replace: true },
    group: { refreshModel: true },
    exclude_usernames: { refreshModel: true },
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
        lastUpdatedAt: null,
      });
    }
  },

  beforeModel() {
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      this.replaceWith("discovery");
    }
  },

  model(params) {
    return ajax("/directory-columns.json")
      .then((response) => {
        params.order = params.order || response.directory_columns[0].name;
        return { params, columns: response.directory_columns };
      })
      .catch(popupAjaxError);
  },

  setupController(controller, model) {
    controller.set("columns", model.columns);
    return Promise.all([
      controller.loadGroups(),
      controller.loadUsers(model.params),
    ]);
  },

  @action
  didTransition() {
    this.controllerFor("users")._showFooter();
    return true;
  },
});
