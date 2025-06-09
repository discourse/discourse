import { get } from "@ember/object";
import Route from "@ember/routing/route";
import { service } from "@ember/service";
import Badge from "discourse/models/badge";
import { i18n } from "discourse-i18n";

export default class AdminBadgesShowRoute extends Route {
  @service dialog;
  @service adminBadges;

  serialize(model) {
    return { badge_id: get(model, "id") || "new" };
  }

  async model(params) {
    await this.adminBadges.fetchBadges();

    if (params.badge_id === "new") {
      return Badge.create({
        name: i18n("admin.badges.new_badge"),
        enabled: true,
        badge_type_id: this.adminBadges.badgeTypes[0].id,
        badge_grouping_id: this.adminBadges.badgeGroupings[0].id,
        trigger: this.adminBadges.badgeTriggers[0].id,
      });
    }

    return this.adminBadges.badges.findBy("id", parseInt(params.badge_id, 10));
  }
}
