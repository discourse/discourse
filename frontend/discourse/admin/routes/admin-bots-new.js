import { loadApiKeyScopes } from "discourse/admin/lib/api-key-scopes";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminBotsNewRoute extends DiscourseRoute {
  async model() {
    const defaults = await ajax("/admin/users/bots/new.json");
    const apiKeyScopes = await loadApiKeyScopes();
    return { ...defaults, apiKeyScopes };
  }

  titleToken() {
    return i18n("admin.users.bots.new");
  }
}
