import { loadApiKeyScopes } from "discourse/admin/lib/api-key-scopes";
import { RouteException } from "discourse/controllers/exception";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminBotsNewRoute extends DiscourseRoute {
  beforeModel() {
    if (!this.currentUser?.admin) {
      throw new RouteException({
        status: 403,
        desc: i18n("admin.users.bots.admins_only"),
      });
    }
  }

  async model() {
    const [defaults, apiKeyScopes] = await Promise.all([
      ajax("/admin/users/bots/new.json"),
      loadApiKeyScopes(),
    ]);
    return { ...defaults, apiKeyScopes };
  }

  titleToken() {
    return i18n("admin.users.bots.new");
  }
}
