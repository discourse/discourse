import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import StoreService from "discourse/services/store";

const DEFAULT_VALUES = {
  field_type: "text",
  requirement: "optional",
  show_on_signup: true,
};

export default class AdminUserFieldsNewRoute extends DiscourseRoute {
  @service(() => StoreService) store;

  async model() {
    return this.store.createRecord("user-field", { ...DEFAULT_VALUES });
  }

  titleToken() {
    return i18n("admin.user_fields.new_header");
  }
}
