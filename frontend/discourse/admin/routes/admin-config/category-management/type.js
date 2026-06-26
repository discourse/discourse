import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigCategoryManagementTypeRoute extends DiscourseRoute {
  model(params) {
    return params.category_type_id;
  }

  titleToken() {
    const categoryTypeId = this.paramsFor(
      "adminConfig.categoryManagement.type"
    ).category_type_id;

    return i18n(
      `admin.config.category_management.types.${categoryTypeId}.title`
    );
  }
}
