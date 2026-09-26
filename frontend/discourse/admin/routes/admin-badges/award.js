import { service } from "discourse/lib/service";
import Route from "discourse/routes/discourse";
import AdminBadgesService from "discourse/admin/services/admin-badges";

export default class AdminBadgesAwardRoute extends Route {
  @service(() => AdminBadgesService) adminBadges;

  async model(params) {
    await this.adminBadges.fetchBadges();

    if (params.badge_id === "new") {
      return;
    }

    return this.adminBadges.badges.find(
      (value) => value.id === parseInt(params.badge_id, 10)
    );
  }
}
