import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminApiKeysIndexRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.api_keys.title");
  }

  model() {
    return this.store.findAll("api-key");
  }
}
