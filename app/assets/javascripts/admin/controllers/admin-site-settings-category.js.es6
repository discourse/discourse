import discourseComputed from "discourse-common/utils/decorators";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";

export default Controller.extend({
  categoryNameKey: null,
  adminSiteSettings: inject(),

  @discourseComputed("adminSiteSettings.visibleSiteSettings", "categoryNameKey")
  category(categories, nameKey) {
    return (categories || []).findBy("nameKey", nameKey);
  },

  @discourseComputed("category")
  filteredContent(category) {
    return category ? category.siteSettings : [];
  }
});
