import Controller, { inject as controller } from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";

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
  },
});
