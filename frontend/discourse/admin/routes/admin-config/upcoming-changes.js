import { service } from "discourse/lib/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import CurrentUserService from "discourse/services/current-user";

export default class AdminConfigUpcomingChangesRoute extends DiscourseRoute {
  @service(() => CurrentUserService) currentUser;

  // registered so in-app links carrying the param keep working: an Ember
  // transitionTo (notification clicks, admin search, the setting-change
  // warning links) rebuilds the URL from registered query params only
  queryParams = {
    changeNamesFilter: { replace: true },
  };

  titleToken() {
    return i18n("admin.config.upcoming_changes.title");
  }

  model() {
    return ajax(
      "/admin/config/upcoming-changes?filter_statuses=experimental,alpha,beta,stable"
    ).then((result) => result.upcoming_changes);
  }

  activate() {
    this.currentUser.set("has_new_upcoming_changes", false);
  }
}
