import discourseComputed from "discourse-common/utils/decorators";
import Controller, { inject as controller } from "@ember/controller";

export default Controller.extend({
  adminSiteSettings: controller(),
  categoryNameKey: null,

  @discourseComputed("adminSiteSettings.visibleSiteSettings", "categoryNameKey")
  category(categories, nameKey) {
    return (categories || []).findBy("nameKey", nameKey);
  },

  @discourseComputed("category")
  filteredContent(category) {
    return category ? category.siteSettings : [];
  }
});
