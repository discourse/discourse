import { action, get } from "@ember/object";
import Route from "@ember/routing/route";
import { service } from "@ember/service";
import Badge from "discourse/models/badge";
import I18n from "discourse-i18n";

export default class AdminBadgesShowRoute extends Route {
  @service dialog;

  serialize(m) {
    return { badge_id: get(m, "id") || "new" };
  }

  model(params) {
    if (params.badge_id === "new") {
      return Badge.create({
        name: I18n.t("admin.badges.new_badge"),
      });
    }
    return this.modelFor("adminBadges").findBy(
      "id",
      parseInt(params.badge_id, 10)
    );
  }

  setupController(controller) {
    super.setupController(...arguments);

    controller.setup();
  }

  @action
  updateGroupings(groupings) {
    this.controllerFor("admin-badges").set("badgeGroupings", groupings);
  }
}
