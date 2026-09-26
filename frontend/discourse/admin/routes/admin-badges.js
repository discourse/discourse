import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import AdminBadgesService from "discourse/admin/services/admin-badges";

export default class AdminBadgesRoute extends DiscourseRoute {
  @service(() => AdminBadgesService) adminBadges;

  titleToken() {
    return i18n("admin.config.badges.title");
  }

  async model() {
    await this.adminBadges.fetchBadges();
  }
}
