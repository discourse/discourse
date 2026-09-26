import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";
import AdminBadgesService from "discourse/admin/services/admin-badges";

export default class AdminBadgesIndexRoute extends Route {
  @service(() => AdminBadgesService) adminBadges;

  async model() {
    await this.adminBadges.fetchBadges();
  }
}
