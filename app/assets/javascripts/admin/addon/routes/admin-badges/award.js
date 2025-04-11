import { service } from "@ember/service";
import Route from "discourse/routes/discourse";

export default class AdminBadgesAwardRoute extends Route {
  @service adminBadges;

  async model(params) {
    await this.adminBadges.fetchBadges();

    if (params.badge_id === "new") {
      return;
    }

    return this.adminBadges.badges.findBy("id", parseInt(params.badge_id, 10));
  }
}
