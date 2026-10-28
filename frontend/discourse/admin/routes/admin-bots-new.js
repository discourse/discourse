import { RouteException } from "discourse/controllers/exception";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminBotsNewRoute extends DiscourseRoute {
  beforeModel() {
    if (!this.currentUser?.admin) {
      throw new RouteException({
        status: 403,
        desc: i18n("admin.users.bots.admins_only"),
      });
    }
  }

  model() {
    return ajax("/admin/users/bots/new.json");
  }

  titleToken() {
    return i18n("admin.users.bots.new");
  }
}
