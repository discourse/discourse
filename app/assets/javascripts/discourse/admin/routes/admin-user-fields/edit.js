import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminUserFieldsEditRoute extends DiscourseRoute {
  model(params) {
    return this.store.find("user-field", params.id);
  }

  titleToken() {
    return i18n("admin.user_fields.edit_header");
  }
}
