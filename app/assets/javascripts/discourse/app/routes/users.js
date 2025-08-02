import { service } from "@ember/service";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class Users extends DiscourseRoute {
  @service router;
  @service siteSettings;
  @service currentUser;

  queryParams = {
    period: { refreshModel: true },
    order: { refreshModel: true },
    asc: { refreshModel: true },
    name: { refreshModel: false, replace: true },
    group: { refreshModel: true },
    exclude_groups: { refreshModel: true },
    exclude_usernames: { refreshModel: true },
  };

  titleToken() {
    return i18n("directory.title");
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.setProperties({
        period: "weekly",
        order: "likes_received",
        asc: null,
        name: "",
        group: null,
        exclude_usernames: null,
        exclude_groups: null,
        lastUpdatedAt: null,
      });
    }
  }

  beforeModel() {
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      this.router.replaceWith("discovery");
    }
  }

  model(params) {
    return ajax("/directory-columns.json")
      .then((response) => {
        params.order =
          params.order ||
          response.directory_columns[0]?.name ||
          "likes_received";
        return { params, columns: response.directory_columns };
      })
      .catch(popupAjaxError);
  }

  setupController(controller, model) {
    controller.set("columns", model.columns);
    return Promise.all([
      controller.loadGroups(),
      controller.loadUsers(model.params),
    ]);
  }
}
