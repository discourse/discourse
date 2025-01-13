import Controller, { inject as controller } from "@ember/controller";
import discourseComputed from "discourse/lib/decorators";

export default class AdminSiteSettingsCategoryController extends Controller {
  @controller adminSiteSettings;

  categoryNameKey = null;

  @discourseComputed("adminSiteSettings.visibleSiteSettings", "categoryNameKey")
  category(categories, nameKey) {
    return (categories || []).findBy("nameKey", nameKey);
  }

  @discourseComputed("category")
  filteredContent(category) {
    return category ? category.siteSettings : [];
  }
}
