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
        groupOptions: null,
      });
    }
  }

  beforeModel() {
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      this.router.replaceWith("discovery");
    }
  }

  async model(params) {
    if (!this.columns) {
      try {
        const response = await ajax("/directory-columns.json");
        this.columns = response.directory_columns;
      } catch (error) {
        popupAjaxError(error);
        throw error;
      }
    }

    params.order ||= this.columns[0]?.name || "likes_received";
    return { params, columns: this.columns };
  }

  setupController(controller, { columns, params }) {
    controller.set("columns", columns);
    const promises = [controller.loadUsers(params)];

    // Only load groups on first load, not on every refresh
    if (!controller.groupOptions) {
      promises.push(controller.loadGroups());
    }

    return Promise.all(promises);
  }
}
