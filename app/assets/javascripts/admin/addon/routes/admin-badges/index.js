import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminBadgesIndexRoute extends Route {
  @service adminBadges;

  async model() {
    await this.adminBadges.fetchBadges();
  }
}
