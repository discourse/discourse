import Badge from "discourse/models/badge";
import BadgeGrouping from "discourse/models/badge-grouping";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";

export default class AdminBadgesRoute extends DiscourseRoute {
  _json = null;

  async model() {
    let json = await ajax("/admin/badges.json");
    this._json = json;
    return Badge.createFromJson(json);
  }

  setupController(controller, model) {
    const json = this._json;
    const badgeTriggers = [];
    const badgeGroupings = [];

    Object.keys(json.admin_badges.triggers).forEach((k) => {
      const id = json.admin_badges.triggers[k];
      badgeTriggers.push({
        id,
        name: I18n.t("admin.badges.trigger_type." + k),
      });
    });

    json.badge_groupings.forEach(function (badgeGroupingJson) {
      badgeGroupings.push(BadgeGrouping.create(badgeGroupingJson));
    });

    controller.badgeGroupings = badgeGroupings;
    controller.badgeTypes = json.badge_types;
    controller.protectedSystemFields =
      json.admin_badges.protected_system_fields;
    controller.badgeTriggers = badgeTriggers;
    controller.model = model;
  }
}
