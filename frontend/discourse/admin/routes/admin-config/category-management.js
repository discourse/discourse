import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigCategoryManagementRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.category_management.title");
  }
}
