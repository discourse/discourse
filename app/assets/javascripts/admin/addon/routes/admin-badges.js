import { ajax } from "discourse/lib/ajax";
import Badge from "discourse/models/badge";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminBadgesRoute extends DiscourseRoute {
  _json = null;

  titleToken() {
    return i18n("admin.config.badges.title");
  }

  async model() {
    let json = await ajax("/admin/badges.json");
    this._json = json;
    return Badge.createFromJson(json);
  }

  setupController(controller, model) {
    controller.model = model;
  }
}
