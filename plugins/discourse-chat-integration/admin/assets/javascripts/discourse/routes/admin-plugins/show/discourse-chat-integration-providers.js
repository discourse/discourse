import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseChatIntegrationProviders extends DiscourseRoute {
  model() {
    return ajax(
      "/admin/plugins/discourse-chat-integration/providers.json"
    ).then((result) => {
      return {
        enabled_providers: result.enabled_providers,
        available_providers: result.available_providers,
      };
    });
  }
}
