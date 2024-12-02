import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

const DEFAULT_VALUES = {
  field_type: "text",
  requirement: "optional",
};

export default class AdminUserFieldsNewRoute extends DiscourseRoute {
  @service store;

  async model() {
    return this.store.createRecord("user-field", { ...DEFAULT_VALUES });
  }

  titleToken() {
    return i18n("admin.user_fields.new_header");
  }
}
