import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigCategoryManagementTypeRoute extends DiscourseRoute {
  @service site;

  model(params) {
    if (params.category_type_id === "all") {
      return {
        id: "all",
        name: i18n("admin.config.category_management.types.all.title"),
        title: i18n("admin.config.category_management.types.all.title"),
        description: i18n(
          "admin.config.category_management.types.all.description"
        ),
        available: true,
        visible: true,
      };
    }

    return this.site.category_types.find(
      (type) => type.id === params.category_type_id
    );
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
