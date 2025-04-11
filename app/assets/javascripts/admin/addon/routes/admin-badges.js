import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminBadgesRoute extends DiscourseRoute {
  @service adminBadges;

  titleToken() {
    return i18n("admin.config.badges.title");
  }

  async model() {
    await this.adminBadges.fetchBadges();
  }
}
