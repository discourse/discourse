import { get } from "@ember/object";
import Route from "@ember/routing/route";
import { service } from "@ember/service";
import Badge from "discourse/models/badge";
import { i18n } from "discourse-i18n";

export default class AdminBadgesShowRoute extends Route {
  @service dialog;

  serialize(m) {
    return { badge_id: get(m, "id") || "new" };
  }

  model(params) {
    if (params.badge_id === "new") {
      return Badge.create({
        name: i18n("admin.badges.new_badge"),
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
}
